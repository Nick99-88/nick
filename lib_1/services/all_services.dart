// Core Services
export 'api_service.dart';
export 'contact_service.dart';
export 'fcm_service.dart';
export 'gemini_service.dart';
export 'marksheet_service.dart';
export 'notification_service.dart';
export 'paper_scanner_service.dart';
export 'timing_service.dart';

// Auth Services
export 'auth/api_debug_service.dart';
export 'auth/app_identity_service.dart';
export 'auth/auth_service.dart';
export 'auth/bootstrap_service.dart';
export 'auth/chat_access_service.dart';
export 'auth/firebase_phone_service.dart';
export 'auth/identity_service.dart';
export 'auth/simple_api_test.dart';
export 'auth/support_service.dart';
export 'auth/user_profile_service.dart';
export 'auth/user_roles_service.dart';

// Chat Services
export 'chat/backend_chat_service.dart' hide MessageStatus;
export 'chat/chat_service.dart';
export 'chat/privacy_chat_service.dart';

// FCM Services
export 'fcm/universal_fcm_service.dart';

// Institution Services
export 'institution/blueprint_service.dart';
export 'institution/dashboard_service.dart';
export 'institution/dictionary_service.dart';
export 'institution/directory_service.dart';
export 'institution/document_service.dart';
export 'institution/fee_service.dart';
export 'institution/institution_profile_service.dart';
export 'institution/institution_service.dart';
export 'institution/notice_service.dart';
export 'institution/profile_service.dart';

// Logging Services
export 'logging/chat_logger.dart';

// ML Services
export 'ml/ml_service.dart';

// Payment Services
export 'payment/google_pay_service.dart';

// QR Services
export 'qr/qr_service.dart';
export 'qr/qr_service_v2.dart';

// Setup Services
export 'setup/setup_service.dart';

// Social Services
export 'social/explore_service.dart';

// Socket Services
export 'socket/enhanced_socket_service.dart';
export 'socket/socket_service.dart';
export 'socket/socket_service_instance.dart' hide SocketService;
export 'socket/unified_socket_service.dart';

// Storage Services
export 'storage/local_manifest_service.dart';

// Subscription Services
export 'subscription/subscription_service.dart';
