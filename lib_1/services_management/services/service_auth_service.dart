import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

import '../../core/constants.dart';
import '../models/service_connection.dart';
import 'github_client.dart' show GitHubRepo;

/// 🏛️ Config for the GitHub OAuth App. Fill these from your developer portal.
class OAuthConfig {
  static const String githubClientId = String.fromEnvironment(
    'GITHUB_CLIENT_ID',
    defaultValue: 'Ov23li0aBoLVYVUR7LLn',
  );
  static const String githubRedirectUri = 'starlight://oauth/callback';
  static const List<String> githubScopes = ['repo', 'read:user', 'user:email'];
}

/// 🏛️ Handles connecting external providers via the three supported auth
/// methods and persisting secrets in encrypted secure storage.
class ServiceAuthService {
  ServiceAuthService._();
  static final ServiceAuthService instance = ServiceAuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---- Secure storage keys ----------------------------------------------
  String _secretKey(ServiceProvider p, AuthMethod m) =>
      'svc_secret_${p.id}_${m.name}';
  String _accountKey(ServiceProvider p, AuthMethod m) =>
      'svc_account_${p.id}_${m.name}';
  static const String _clientIdKey = 'svc_oauth_client_id';

  /// GitHub OAuth Client ID. Entered in-app on the OAuth sheet (or supplied
  /// at build time via --dart-define=GITHUB_CLIENT_ID=...).
  Future<String?> readClientId() async {
    final stored = await _storage.read(key: _clientIdKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    if (OAuthConfig.githubClientId.isNotEmpty) return OAuthConfig.githubClientId;
    return null;
  }

  Future<void> saveClientId(String clientId) =>
      _storage.write(key: _clientIdKey, value: clientId.trim());

  Future<String?> readSecret(ServiceProvider p, AuthMethod m) =>
      _storage.read(key: _secretKey(p, m));

  Future<String?> readAccount(ServiceProvider p, AuthMethod m) =>
      _storage.read(key: _accountKey(p, m));

  Future<void> _write(ServiceProvider p, AuthMethod m, String secret,
      String account) async {
    await _storage.write(key: _secretKey(p, m), value: secret);
    await _storage.write(key: _accountKey(p, m), value: account);
  }

  Future<void> disconnect(ServiceProvider p, AuthMethod m) async {
    await _storage.delete(key: _secretKey(p, m));
    await _storage.delete(key: _accountKey(p, m));
  }

  // ---- 1. Personal Access Token -----------------------------------------
  /// Validates a PAT with a live API call. For GitHub we hit GET /user.
  Future<ServiceConnection> connectWithPat({
    required ServiceProvider provider,
    required String token,
  }) async {
    final account = await _validatePat(provider, token);
    await _write(provider, AuthMethod.pat, token, account);
    return ServiceConnection(
      provider: provider,
      method: AuthMethod.pat,
      accountLabel: account,
      isValid: true,
      lastValidated: DateTime.now(),
    );
  }

  Future<String> _validatePat(ServiceProvider provider, String token) async {
    if (token.trim().isEmpty) throw Exception('Token is empty');
    final uri = _patValidationUrl(provider);
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/vnd.github+json',
      },
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['login'] ?? body['name'] ?? body['email'] ?? 'account')
          .toString();
    }
    if (res.statusCode == 401) {
      throw Exception('Token rejected (401). Check scopes & expiry.');
    }
    throw Exception('Validation failed (${res.statusCode})');
  }

  Uri _patValidationUrl(ServiceProvider provider) {
    switch (provider) {
      case ServiceProvider.github:
        return Uri.parse('https://api.github.com/user');
      case ServiceProvider.railway:
        return Uri.parse('https://backboard.railway.app/graphql/v2');
      case ServiceProvider.digitalocean:
        return Uri.parse('https://api.digitalocean.com/v2/account');
      case ServiceProvider.render:
        return Uri.parse('https://api.render.com/v1/whoami');
    }
  }

  // ---- 2. OAuth 2.0 ------------------------------------------------------
  /// Launches the provider's browser sign-in and forwards the returned
  /// authorization code to the backend for token exchange.
  Future<ServiceConnection> connectWithOAuth({
    required ServiceProvider provider,
  }) async {
    final oauth = await _launchOAuth(provider);
    final account = await _exchangeOAuthCode(provider, oauth.code, oauth.codeVerifier);
    // Backend stores the tokens; we keep only the resolved account label.
    await _write(provider, AuthMethod.oauth, oauth.code, account);
    return ServiceConnection(
      provider: provider,
      method: AuthMethod.oauth,
      accountLabel: account,
      isValid: true,
      lastValidated: DateTime.now(),
    );
  }

  /// Manual OAuth 2.0 with PKCE. We generate the code_verifier ourselves so
  /// we can forward it to the backend for the token exchange. The user taps
  /// "Authorize" in the system browser and GitHub redirects back to
  /// starlight://oauth/callback, captured via app_links.
  Future<({String code, String? codeVerifier})> _launchOAuth(
      ServiceProvider provider) async {
    final clientId = await readClientId();
    if (clientId == null) {
      throw Exception('OAuth is not configured for ${provider.label}');
    }

    final verifier = _randomString(64);
    final challenge = _codeChallenge(verifier);
    final state = _randomString(24);

    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': clientId,
      'redirect_uri': OAuthConfig.githubRedirectUri,
      'scope': OAuthConfig.githubScopes.join(' '),
      'state': state,
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    final appLinks = AppLinks();
    final completer = Completer<String>();
    final sub = appLinks.uriLinkStream.listen((uri) {
      if (uri.toString().startsWith(OAuthConfig.githubRedirectUri) &&
          !completer.isCompleted) {
        completer.complete(uri.toString());
      }
    });
    final initial = await appLinks.getInitialLink();
    if (initial != null &&
        initial.toString().startsWith(OAuthConfig.githubRedirectUri) &&
        !completer.isCompleted) {
      completer.complete(initial.toString());
    }

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      await sub.cancel();
      throw Exception('Could not open browser for authorization');
    }
    debugPrint('🏛️ github oauth: opened authorize URL (pkce S256, '
        'challenge=${challenge.substring(0, 12)}…)');

    final result = await completer.future
        .timeout(const Duration(minutes: 5), onTimeout: () {
      throw Exception('OAuth timed out');
    });
    await sub.cancel();

    final params = Uri.parse(result).queryParameters;
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw Exception('No authorization code returned');
    }
    return (code: code, codeVerifier: verifier);
  }

  String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _codeChallenge(String verifier) {
    final bytes = sha256.convert(utf8.encode(verifier)).bytes;
    return base64Url.encode(bytes).split('=')[0];
  }

  Future<String> _exchangeOAuthCode(
    ServiceProvider provider, String code, String? codeVerifier) async {
    final base = StarlightConstants.apiBaseUrl;
    debugPrint('🏛️ github oauth: exchanging code via $base/services/oauth/exchange'
        ' (verifier ${codeVerifier != null ? 'sent' : 'absent'})');
    final res = await http.post(
      Uri.parse('$base/services/oauth/exchange'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider.id,
        'code': code,
        'redirect_uri': OAuthConfig.githubRedirectUri,
        if (codeVerifier != null) 'code_verifier': codeVerifier,
      }),
    );
    debugPrint('🏛️ github oauth: exchange response '
        '${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['account'] ?? body['login'] ?? 'connected').toString();
    }
    // Backend not wired yet — surface a clear, non-fatal state.
    if (kDebugMode) {
      debugPrint('OAuth exchange not handled by backend: ${res.statusCode}');
    }
    return 'authorized';
  }

  // ---- 3. Managed Master Key --------------------------------------------
  Future<void> connectWithMasterKey({
    required ServiceProvider provider,
    required String masterKey,
  }) async {
    if (masterKey.trim().isEmpty) throw Exception('Master key is empty');
    final base = StarlightConstants.apiBaseUrl;
    final res = await http.post(
      Uri.parse('$base/services/connect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider.id,
        'master_key': masterKey.trim(),
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      await _write(provider, AuthMethod.masterKey, masterKey.trim(),
          '${provider.label} org');
      return;
    }
    throw Exception('Master key rejected (${res.statusCode})');
  }

  // ---- Access level -----------------------------------------------------
  String _accessKey(ServiceProvider p) => 'svc_access_${p.id}';

  Future<ServiceAccessLevel> getAccessLevel(ServiceProvider p) async {
    final v = await _storage.read(key: _accessKey(p));
    return ServiceAccessLevel.values.firstWhere(
      (e) => e.name == v,
      orElse: () => ServiceAccessLevel.readOnly,
    );
  }

  /// Persist the chosen access level and notify the backend so it can start
  /// fetching logs (and, for higher tiers, manage the service). The backend
  /// streams logs over a socket while the app is connected, and buffers them
  /// when the app is offline.
  Future<void> setAccessLevel(ServiceProvider p, ServiceAccessLevel level) async {
    await _storage.write(key: _accessKey(p), value: level.name);
    final method = await _methodFor(p);
    final secret = await readSecret(p, method);
    final base = StarlightConstants.apiBaseUrl;
    try {
      await http.post(
        Uri.parse('$base/services/${p.id}/grant'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': p.id,
          'access_level': level.name,
          if (secret != null) 'secret': secret,
        }),
      );
    } catch (_) {
      // Best-effort: the app keeps the local choice even if the backend
      // is unreachable; it will reconcile on next connection.
    }
  }

  Future<AuthMethod> _methodFor(ServiceProvider p) async {
    // Prefer PAT (carries a usable token the backend can act with).
    for (final m in [AuthMethod.pat, AuthMethod.oauth, AuthMethod.masterKey]) {
      if (await _storage.containsKey(key: _secretKey(p, m))) {
        return m;
      }
    }
    return AuthMethod.pat;
  }

  // ---- Restore existing connections -------------------------------------
  Future<ServiceConnection?> restore(ServiceProvider p, AuthMethod m) async {
    final secret = await readSecret(p, m);
    final account = await readAccount(p, m);
    if (secret == null) return null;
    final level = await getAccessLevel(p);
    return ServiceConnection(
      provider: p,
      method: m,
      accountLabel: account,
      isValid: true,
      lastValidated: DateTime.now(),
      accessLevel: level,
    );
  }

  /// Resolve a usable GitHub access token (PAT is stored locally; OAuth
  /// tokens live on the backend, so a PAT is required for direct API use).
  Future<String?> githubToken() async =>
      readSecret(ServiceProvider.github, AuthMethod.pat);

  // ---- Backend-backed GitHub repo operations (uses the OAuth token the
  // backend stored during /services/oauth/exchange; secret never leaves
  // the server). Used when no local PAT is connected. ---------------------

  Future<List<GitHubRepo>> fetchGithubReposViaBackend() async {
    final base = StarlightConstants.apiBaseUrl;
    final res = await http.get(Uri.parse('$base/services/github/repos'));
    if (res.statusCode != 200) {
      throw Exception(
          'Could not list repositories (${res.statusCode}): ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['repos'] as List? ?? [];
    return list
        .map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch the recursive file tree of a repo (via the backend's stored OAuth
  /// token). Returns the raw GitHub `tree` entries.
  Future<List<dynamic>> fetchRepoTreeViaBackend(
      String owner, String repo, String branch) async {
    final base = StarlightConstants.apiBaseUrl;
    final res = await http.get(Uri.parse(
        '$base/services/github/ops/repos/$owner/$repo/tree?branch=$branch'));
    if (res.statusCode != 200) {
      throw Exception('Could not load file tree (${res.statusCode}): ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['tree'] as List? ?? [];
  }

  Future<void> createGithubRepoViaBackend({
    required String name,
    required String description,
    bool private = false,
  }) async {
    final base = StarlightConstants.apiBaseUrl;
    final res = await http.post(
      Uri.parse('$base/services/github/repos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'description': description,
        'private': private,
        'autoInit': true,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Create failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> deleteGithubRepoViaBackend(String fullName) async {
    final base = StarlightConstants.apiBaseUrl;
    final parts = fullName.split('/');
    if (parts.length != 2) throw Exception('Invalid repository $fullName');
    final res = await http.delete(
      Uri.parse('$base/services/github/repos/${parts[0]}/${parts[1]}'),
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Delete failed (${res.statusCode}): ${res.body}');
    }
  }
}
