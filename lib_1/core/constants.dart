class StarlightConstants {
  // 🏛️ Development backend URL (for local testing - change to 10.0.2.2 for Android Emulator)
  static const String devApiBaseUrl = "https://api.institution.site";

  // 🏛️ Production backend URL (HTTPS for Android Safety)
  static const String prodApiBaseUrl = "https://api.institution.site";

  // 🏛️ Current API base URL (switch between dev/prod)
  static const String apiBaseUrl = devApiBaseUrl;

  // 🏛️ The high-speed WebSocket engine (WSS for Secure Social/Wallet)
  static const String socialSocketUrl = "wss://api.institution.site/ws/social";
  static const String chatSocketUrl = "wss://api.institution.site/ws/chat";
  static const String socketUrl = socialSocketUrl; // Default for legacy code
  static const String wsBaseUrl = "wss://api.institution.site"; // Base URL for WebSocket connections

  // 🏛️ Auth Endpoints
  static const String authEndpoint = "$apiBaseUrl/auth";
  static const String identityEndpoint = "$apiBaseUrl/auth/identities";

  // 🏛️ Directory Endpoints
  static const String directoryEndpoint = "$apiBaseUrl/institution/directory";
  static const String directoryStatsEndpoint = "$directoryEndpoint/stats";
  static const String directoryMembersEndpoint = "$directoryEndpoint/members";

  // 🏛️ Video Storage base (override if using separate S3/MinIO)
  static const String videoStorageUrl = "$apiBaseUrl/storage/videos";

  // 🏛️ Chat System Validation Constants
  static const int maxMessageLength = 4000;
  static const int maxUserNameLength = 100;
  static const int maxUserId = 999999999;
  static const int maxChatId = 999999999;
  static const int maxMetadataSize = 50; // Maximum number of metadata key-value pairs
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB in bytes
}
