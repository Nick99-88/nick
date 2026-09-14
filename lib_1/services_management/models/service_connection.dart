import 'package:flutter/material.dart';

/// 🏛️ Provider registry for external service integrations.
enum ServiceProvider {
  github,
  railway,
  digitalocean,
  render;

  String get id => name;

  String get label {
    switch (this) {
      case ServiceProvider.github:
        return 'GitHub';
      case ServiceProvider.railway:
        return 'Railway';
      case ServiceProvider.digitalocean:
        return 'DigitalOcean';
      case ServiceProvider.render:
        return 'Render';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceProvider.github:
        return Icons.code_rounded;
      case ServiceProvider.railway:
        return Icons.train_rounded;
      case ServiceProvider.digitalocean:
        return Icons.cloud_rounded;
      case ServiceProvider.render:
        return Icons.bolt_rounded;
    }
  }

  /// Brand-tinted colour used for accents on light cards.
  Color get accent {
    switch (this) {
      case ServiceProvider.github:
        return const Color(0xFF1A237E);
      case ServiceProvider.railway:
        return const Color(0xFF6A1B9A);
      case ServiceProvider.digitalocean:
        return const Color(0xFF00897B);
      case ServiceProvider.render:
        return const Color(0xFFE65100);
    }
  }

  /// Which authentication methods this provider supports.
  List<AuthMethod> get supportedMethods {
    switch (this) {
      case ServiceProvider.github:
        return const [AuthMethod.oauth, AuthMethod.pat];
      case ServiceProvider.railway:
      case ServiceProvider.digitalocean:
      case ServiceProvider.render:
        return const [AuthMethod.pat, AuthMethod.masterKey];
    }
  }
}

/// 🏛️ Authentication strategy for a connected external service.
enum AuthMethod {
  oauth,
  pat,
  masterKey;

  String get label {
    switch (this) {
      case AuthMethod.oauth:
        return 'OAuth 2.0';
      case AuthMethod.pat:
        return 'Personal Access Token';
      case AuthMethod.masterKey:
        return 'Managed Master Key';
    }
  }

  String get description {
    switch (this) {
      case AuthMethod.oauth:
        return 'Secure browser sign-in. The backend exchanges the '
            'authorization code for rotating access & refresh tokens.';
      case AuthMethod.pat:
        return 'Paste a token from the provider. We validate it with a '
            'live API call and store it encrypted in secure storage.';
      case AuthMethod.masterKey:
        return 'Use a shared organization master key. The backend maps '
            'your account to its own tenanted resources (multi-tenant).';
    }
  }

  IconData get icon {
    switch (this) {
      case AuthMethod.oauth:
        return Icons.open_in_browser_rounded;
      case AuthMethod.pat:
        return Icons.key_rounded;
      case AuthMethod.masterKey:
        return Icons.admin_panel_settings_rounded;
    }
  }
}

/// 🏛️ Access level granted to the Starlight backend for a provider.
enum ServiceAccessLevel {
  readOnly,
  management,
  full;

  String get label {
    switch (this) {
      case ServiceAccessLevel.readOnly:
        return 'Read only / Fetch logs';
      case ServiceAccessLevel.management:
        return 'Management';
      case ServiceAccessLevel.full:
        return 'Complete access';
    }
  }

  String get description {
    switch (this) {
      case ServiceAccessLevel.readOnly:
        return 'Backend may fetch logs & status only. No mutations.';
      case ServiceAccessLevel.management:
        return 'Backend may create/restart services and read logs.';
      case ServiceAccessLevel.full:
        return 'Backend may fully manage the provider on your behalf.';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceAccessLevel.readOnly:
        return Icons.visibility_rounded;
      case ServiceAccessLevel.management:
        return Icons.tune_rounded;
      case ServiceAccessLevel.full:
        return Icons.shield_rounded;
    }
  }
}

/// 🏛️ A persisted connection to an external provider.
class ServiceConnection {
  final ServiceProvider provider;
  final AuthMethod method;
  final String? accountLabel;
  final bool isValid;
  final DateTime? lastValidated;
  final String? error;
  final ServiceAccessLevel accessLevel;

  const ServiceConnection({
    required this.provider,
    required this.method,
    this.accountLabel,
    this.isValid = false,
    this.lastValidated,
    this.error,
    this.accessLevel = ServiceAccessLevel.readOnly,
  });

  ServiceConnection copyWith({
    String? accountLabel,
    bool? isValid,
    DateTime? lastValidated,
    String? error,
    ServiceAccessLevel? accessLevel,
  }) {
    return ServiceConnection(
      provider: provider,
      method: method,
      accountLabel: accountLabel ?? this.accountLabel,
      isValid: isValid ?? this.isValid,
      lastValidated: lastValidated ?? this.lastValidated,
      error: error ?? this.error,
      accessLevel: accessLevel ?? this.accessLevel,
    );
  }

  String get storageKey => 'svc_${provider.id}_${method.name}';
}
