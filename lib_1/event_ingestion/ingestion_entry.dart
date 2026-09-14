/// 🏛️ External Event-Stream Ingestion UI.
///
/// Feature-rich, admin-facing console for the ingestion backend:
///   • Sources     — register WebSocket / Polling / Webhook integrations
///   • Events      — live, filterable ingestion feed with raw-JSON detail
///   • Subscribers — manage FCM critical-alert recipients
///   • Status      — supervisor health, TTL/cooldown config, test push
export 'models/ingestion_models.dart';
export 'services/ingestion_service.dart';
export 'widgets/common.dart';
export 'widgets/cards.dart';
export 'widgets/sheets.dart';
export 'screens/sources_tab.dart';
export 'screens/events_tab.dart';
export 'screens/subscribers_tab.dart';
export 'screens/status_tab.dart';
export 'screens/ingestion_dashboard_screen.dart';
export 'screens/cloud_sources_screen.dart';
