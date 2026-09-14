import 'package:dio/dio.dart';
import '../core/storage.dart';
import '../core/constants.dart';

class PlatformUserProfile {
  final String id;
  final String name;
  final String role;
  final String? avatarUrl;

  const PlatformUserProfile({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  factory PlatformUserProfile.fromJson(Map<String, dynamic> json) {
    return PlatformUserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Explorer',
      role: json['role']?.toString().toLowerCase() ?? 'student',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class PlatformSubscription {
  final String tier;
  final bool isActive;
  final int remainingDays;
  final String? expiresAt;

  const PlatformSubscription({
    required this.tier,
    required this.isActive,
    required this.remainingDays,
    this.expiresAt,
  });

  factory PlatformSubscription.fromJson(Map<String, dynamic> json) {
    return PlatformSubscription(
      tier: json['tier']?.toString() ?? 'free',
      isActive: json['is_active'] == true,
      remainingDays: json['remaining_days'] is int
          ? json['remaining_days']
          : int.tryParse(json['remaining_days']?.toString() ?? '0') ?? 0,
      expiresAt: json['expires_at']?.toString(),
    );
  }
}

class PlatformProject {
  final String title;
  final String networkAddress;
  final String targetUrl;
  final String? htmlContent;
  final String? sideProjectId;

  const PlatformProject({
    required this.title,
    required this.networkAddress,
    required this.targetUrl,
    this.htmlContent,
    this.sideProjectId,
  });

  factory PlatformProject.fromJson(Map<String, dynamic> json) {
    return PlatformProject(
      title: json['title']?.toString() ?? 'Untitled Project',
      networkAddress: json['network_address']?.toString() ?? '',
      targetUrl: json['target_url']?.toString() ?? '',
      htmlContent: json['html_content']?.toString(),
      sideProjectId: json['side_project_id']?.toString(),
    );
  }
}

class PlatformApiException implements Exception {
  final String message;
  final int? statusCode;

  const PlatformApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class PlatformApiService {
  static String baseUrl = StarlightConstants.apiBaseUrl;

  late final Dio _dio;

  PlatformApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StarlightStorage.getUserToken();
        options.headers['Authorization'] = 'Bearer ${token ?? "mock_dev_token"}';
        handler.next(options);
      },
    ));
  }

  Future<PlatformUserProfile> getUserProfile() async {
    try {
      final response = await _dio.get('/platform/profile');
      return PlatformUserProfile.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<PlatformSubscription> getSubscriptionStatus() async {
    try {
      final response = await _dio.get('/platform/subscription');
      return PlatformSubscription.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<PlatformProject>> getHostedProjects() async {
    try {
      final response = await _dio.get('/platform/projects');
      final data = response.data;
      if (data is List) {
        return data.map((j) => PlatformProject.fromJson(j as Map<String, dynamic>)).toList();
      }
      if (data is Map && data['projects'] is List) {
        return (data['projects'] as List)
            .map((j) => PlatformProject.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createWebsite({
    required String name,
    required String framework,
    required List<Map<String, String>> files,
    String? title,
  }) async {
    try {
      final response = await _dio.post('/platform/websites/create', data: {
        'name': name,
        'framework': framework,
        'files': files,
        if (title != null) 'title': title,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<PlatformUserProfile> createDashboard() async {
    try {
      final response = await _dio.post('/platform/dashboard/create');
      return PlatformUserProfile.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  PlatformApiException _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const PlatformApiException('Connection timed out. Check your internet connection.');
      case DioExceptionType.connectionError:
        return const PlatformApiException('No internet connection. Please check your network.');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final detail = e.response?.data is Map
            ? (e.response?.data as Map)['detail']?.toString()
            : null;
        final msg = detail ?? e.response?.statusMessage ?? 'Unknown error';
        switch (status) {
          case 404:
            return PlatformApiException('Resource not found (404): $msg', statusCode: 404);
          case 401:
          case 403:
            return PlatformApiException('Authentication failed ($status): $msg', statusCode: status);
          case 500:
            return PlatformApiException('Server error (500): $msg', statusCode: 500);
          default:
            return PlatformApiException('HTTP $status: $msg', statusCode: status);
        }
      default:
        return const PlatformApiException('Network error. Please try again.');
    }
  }
}
