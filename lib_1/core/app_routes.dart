import 'package:flutter/material.dart';

// Auth Screens
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/identity_screen.dart';
import '../screens/auth/intro_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/phone_verification_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/support_screen.dart';
import '../screens/language_selection_screen.dart';
import '../widgets/intro_widgets/onboarding_overlay.dart';

// Setup Screens
import '../screens/setups/identity_sync_screen.dart';
import '../screens/setups/institutionFormScreen.dart';
import '../screens/setups/owner_setup_screen.dart';
import '../screens/setups/role_selection.dart';
import '../screens/setups/staff_identity_setup.dart';
import '../screens/setups/staff_setup_screen.dart';
import '../screens/setups/student_identity_setup.dart';
import '../screens/setups/teacher-identity-setup.dart';
import '../screens/setups/parent_identity_setup.dart';
import '../screens/setups/parent_child_connection_screen.dart';
import '../screens/setups/parent_connection_screen.dart';
import '../screens/setups/child_connection_screen.dart';
import '../screens/parent/parent_dashboard.dart';

// Core Screens
import '../screens/main_entry_screen.dart' hide ProfileScreen;
import '../screens/ownership_gateway.dart';
import '../screens/splash_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/hub/booksmith_screen.dart';
import '../screens/hub/tts_converter_screen.dart';
import '../side/screens/side_ide_screen.dart';
import '../widgets/students_features_widget.dart';

// Owner Screens
import '../screens/owner/dashboard.dart';
import '../screens/owner/documents_screen.dart';
import '../screens/owner/document_vault_screen.dart';
import '../screens/owner/finance_screen.dart';
import '../screens/owner/HubDashboard.dart';
import '../screens/owner/main_entry_screen.dart' hide MainEntryScreen;
import '../screens/owner/owner_console_screen.dart';
import '../screens/owner/profile_screen.dart' hide ProfileScreen;
import '../screens/owner/staff_access_control.dart';

// Owner Global
import '../screens/owner/analytics/analytics_screen.dart';

// Owner Timetable
import '../timetable_directory/screens/timetable_directory.dart';
import '../screens/hub/booksmith_screen.dart';
import '../screens/hub/tts_converter_screen.dart';
import '../side/screens/side_ide_screen.dart';

// Owner Hub Tabs
import '../screens/owner/hub_tabs/add_user_screen.dart';
import '../screens/owner/hub_tabs/ChatProfileScreen.dart';
import '../screens/owner/hub_tabs/chat_list_screen.dart' as owner_hub;
import '../screens/owner/hub_tabs/chat_message_screen.dart' as owner_hub;
import '../screens/owner/hub_tabs/owner_chat_verification_screen.dart' as owner_hub;
import '../screens/owner/hub_tabs/user_roles_screen.dart';

// Owner Profile Tabs
import '../screens/owner/profile_tabs/ActivityLogs.dart';
import '../screens/owner/profile_tabs/AdvancedSecurity.dart';
import '../screens/owner/profile_tabs/BlockedList.dart';
import '../screens/owner/profile_tabs/InstitutionalTimingScreen.dart';
import '../screens/owner/profile_tabs/InstitutionDirectory.dart';
import '../screens/owner/profile_tabs/LimitedAccessScreen.dart';
import '../screens/owner/profile_tabs/PersonalInformation.dart';
import '../screens/owner/profile_tabs/ProfessionalBio.dart';
import '../screens/owner/profile_tabs/RolesList.dart';
import '../screens/shared/settings_screen.dart';
import '../screens/owner/profile_tabs/verify_identities_screen.dart';
import '../screens/owner/profile_tabs/link_identities_screen.dart';

// Owner Tabs
import '../screens/owner/tabs/dashboard_home_tab.dart';
import '../screens/owner/tabs/dictionary_screen.dart';
import '../screens/owner/tabs/faculty_directory_screen.dart';
import '../screens/owner/tabs/section_list_screen.dart';
import '../screens/owner/tabs/staff_directory_screen.dart';
import '../screens/owner/tabs/staff_hiring_screen.dart';
import '../screens/owner/tabs/StudentListScreen.dart';
import '../screens/owner/tabs/student_admission_screen.dart';
import '../screens/owner/tabs/teacher_hiring_screen.dart';

// Teacher Screens
import '../screens/teacher/dashboard.dart';
import '../screens/teacher/hub.dart';
import '../screens/teacher/main_teacher_screen.dart';
import '../screens/teacher/paper.dart';
import '../screens/teacher/profile.dart';
import '../screens/teacher/chat/chat_list_screen.dart';
import '../screens/teacher/chat/chat_message_screen.dart';
import '../screens/teacher/chat/chat_verification_screen.dart';

// Student Screens
import '../screens/student/dashboard.dart' hide StudentDashboard;
import '../screens/student/doc.dart';
import '../screens/student/hub.dart';
import '../screens/student/main_student_screen.dart';
import '../screens/student/profile.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/student/chat/chat_list_screen.dart';
import '../screens/student/chat/chat_message_screen.dart' hide ChatMessageScreen;
import '../screens/student/chat/chat_verification_screen.dart';
import '../side/screens/challenges_screen.dart';

// Staff Screens
import '../screens/staff/staff_dashboard.dart';
import '../screens/staff/staff_institution_search_screen.dart';
import '../screens/staff/staff_main_screen.dart';

// Social Screens
import '../screens/social/explore_screen.dart';
import '../screens/social/student_explore_screen.dart';
import '../screens/social/full_profile_screen.dart';
import '../screens/social/social_main_screen.dart';
import '../screens/social/vault_browser_screen.dart';
import '../screens/social/developer_dashboard_screen.dart';
import '../screens/social/inbox_screen.dart';
import '../screens/social/ai_assistant_screen.dart';
import '../screens/social/widgets/institution_card.dart';
import '../screens/social/widgets/user_card.dart';

// Hub Screens
import '../screens/hub/wallet_screen.dart';

// Mail Box Screens
import '../screens/mail_box/compose_screen.dart';
import '../screens/mail_box/sent_screen.dart';

// Store Screens
import '../screens/store/subscription_store_screen.dart';

// Shop Screens
import '../shop/shop_screen.dart';

// Chat System Screens
import '../chat_system/chat_system_entry.dart' as chat_system;
import '../chat_system/screens/isolated_call_screen.dart';
import '../chat_system/screens/unified_call_screen.dart';
import '../screens/social/chat_screen.dart';

// Owner Doc Tabs
import '../screens/owner/doc_tabs/advanced_notes_screen.dart';
import '../screens/owner/doc_tabs/attendance_blueprint_vault.dart';
import '../screens/owner/doc_tabs/blueprint_editor.dart';
import '../screens/owner/doc_tabs/blueprint_overlay.dart';
import '../screens/owner/doc_tabs/datesheet_architect.dart';
import '../screens/owner/doc_tabs/document_hub.dart';
import '../screens/owner/doc_tabs/document_scanner_screen.dart';
import '../screens/owner/doc_tabs/enhanced_paper_scanner.dart';
import '../screens/owner/doc_tabs/fee_voucher_data_entry.dart';
import '../screens/owner/doc_tabs/fee_voucher_editor.dart';
import '../screens/owner/doc_tabs/marksheet_page.dart';
import '../screens/owner/doc_tabs/my_files_screen.dart';
import '../screens/owner/doc_tabs/notice_architect.dart';
import '../screens/owner/doc_tabs/paper_architect.dart';
import '../screens/owner/doc_tabs/paper_scanner_architect.dart';
import '../screens/owner/doc_tabs/qr_scanner_vault.dart';
import '../screens/owner/doc_tabs/question_vault_generator.dart';
import '../screens/owner/doc_tabs/question_vault_manager.dart';
import '../screens/owner/doc_tabs/staff_attendance_architect.dart';
import '../screens/owner/doc_tabs/student_attendance_architect.dart';
import '../screens/owner/doc_tabs/document_translator.dart';
import '../screens/owner/doc_tabs/quiz.dart';
import '../screens/owner/doc_tabs/contextual_quiz_screen.dart';
import '../screens/owner/doc_tabs/syllabus_page.dart';
import '../screens/owner/doc_tabs/testArchitect.dart';

// QR Portal Models
import '../qr_portal/models/professional_content_model.dart';
import '../qr_portal/models/qr_link_model.dart';

// QR Portal Screens
import '../qr_portal/qr_portal_screen.dart';
import '../qr_portal/screens/content_detail_screen.dart';
import '../qr_portal/screens/create_content_screen.dart';
import '../qr_portal/screens/link_content_search_screen.dart';
import '../qr_portal/screens/professional_content_list_screen.dart';
import '../qr_portal/screens/qr_code_display_screen.dart';
import '../qr_portal/screens/qr_content_display_screen.dart';
import '../qr_portal/screens/qr_link_search_screen.dart';
import '../qr_portal/screens/qr_result_screen.dart';
import '../qr_portal/screens/qr_scanner_screen.dart';
import '../qr_portal/widgets/analytics_dashboard.dart';
import '../qr_portal/widgets/professional_content_card.dart';
import '../qr_portal/widgets/qr_link_card.dart';

// Widgets
import '../widgets/coin_display_widget.dart';
import '../widgets/navigation_handler.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/starlight_mailbox.dart';
import '../widgets/starlight_nav_bar.dart';

// Event Ingestion Console
import '../event_ingestion/screens/ingestion_dashboard_screen.dart';
import '../services_management/screens/services_management_screen.dart';
import '../services_management/screens/github_repos_screen.dart';

// Services (barrel export)
import '../services/all_services.dart';

// Core Utilities
import 'action_engine.dart';
import 'constants.dart';
import 'database_helper.dart';
import 'data_router.dart';
import 'db_functions.dart';
import 'firebase_options.dart';
import 'identity_controller.dart';
import 'loading.dart';
import 'ml_config.dart';
import 'notification_service.dart';
import 'permission_dialog.dart';
import 'platform_gate.dart';
import 'router_gateway.dart';
import 'sign.dart';
import 'socket_vault.dart';
import 'starlight_secure_storage.dart';
import 'storage.dart';
import 'theme.dart';
import 'utils.dart';
import 'ai_model_manager.dart';

// Local DB (barrel export)
import '../local_db/all_local_db.dart';

// Models
import '../models/scanned_question_models.dart';
import '../models/subscription_models.dart';
import '../models/institution/institution_model.dart';
import '../models/staff/staff_join_request.dart';

// Chat Local DB
import '../chat_local_db/chat_local_db.dart';
import '../chat_local_db/usage_example.dart';
import '../chat_local_db/database/chat_local_database.dart';
import '../chat_local_db/models/local_chat.dart';
import '../chat_local_db/models/local_message.dart';
import '../chat_local_db/models/media_info.dart';
import '../chat_local_db/models/models.dart';
import '../chat_local_db/repositories/chat_repository.dart';
import '../chat_local_db/repositories/media_repository.dart';
import '../chat_local_db/repositories/message_repository.dart';
import '../chat_local_db/repositories/repositories.dart';
import '../chat_local_db/services/chat_local_service.dart';
import '../chat_local_db/services/services.dart';
import '../chat_local_db/storage/chat_media_storage.dart';
import '../chat_local_db/storage/storage.dart';

import '../chatting_rooms/screens/rtc_lobby_screen.dart';

// Widgets
import '../widgets/ai_packages_widget.dart';

class AppRoutes {
  // Engine & Splash
  static const String engine = '/';
  static const String splash = '/splash';
  static const String languageSelection = '/language-selection';
  static const String intro = '/intro';
  static const String onboarding = '/onboarding';

  // Auth Routes
  static const String login = '/login';
  static const String signup = '/signup';
  static const String identityHub = '/identity-hub';
  static const String phoneVerification = '/phone-verification';
  static const String forgotPassword = '/forgot-password';
  static const String otpVerification = '/otp-verification';
  static const String resetPassword = '/reset-password';
  static const String support = '/support';

  // Setup Routes
  static const String roleSelection = '/role-selection';
  static const String ownerIdentity = '/owner-identity-setup';
  static const String teacherIdentity = '/teacher-identity-setup';
  static const String studentIdentity = '/student-identity-setup';
  static const String staffIdentity = '/staff-identity-setup';
  static const String parentIdentity = '/parent-identity-setup';
  static const String parentChildConnection = '/parent-child-connection';
  static const String parentConnection = '/parent-connection';
  static const String childConnection = '/child-connection';
  static const String parentDashboard = '/parent-dashboard';
  static const String institutionSetup = '/institution-setup';
  static const String OwnershipCheckVerification = '/ownership-verification';
  static const String identitySync = '/identity-sync';
  static const String staffSetup = '/staff-setup';

  // Main Dashboard Routes
  static const String dashboard = '/main_entry_screen';
  static const String institutionalDashboard = '/institutional-dashboard';
  static const String ownerDashboard = '/owner-dashboard';
  static const String ownerProfile = '/owner-profile';
  static const String ownerProfileScreen = '/owner-profile-screen';
  static const String ownerDocuments = '/owner-documents';
  static const String ownerDocumentVault = '/owner-document-vault';
  static const String ownerFinance = '/finance';
  static const String ownerStaffAccess = '/owner-staff-access';
  static const String ownerConsole = '/owner-console';

  // Owner Doc Tabs Routes
  static const String advancedNotes = '/notes';
  static const String attendanceBlueprintVault = '/attendance-blueprint-vault';
  static const String blueprintEditor = '/blueprint-editor';
  static const String blueprintOverlay = '/blueprint-overlay';
  static const String datesheetArchitect = '/datesheet-architect';
  static const String dictionaryPage = '/dictionary-page';
  static const String documentHub = '/document-hub';
  static const String documentScanner = '/document-scanner';
  static const String documentStructuralScanner = '/document-structural-scanner';
  static const String enhancedPaperScanner = '/enhanced-paper-scanner';
  static const String feeVoucherDataEntry = '/fee-voucher-data-entry';
  static const String feeVoucherEditor = '/fee-voucher-editor';
  static const String marksheetPage = '/marksheet-page';
  static const String myFiles = '/my-files';
  static const String noticeArchitect = '/notice-architect';
  static const String paperArchitect = '/paper-architect';
  static const String paperScannerArchitect = '/paper-scanner-architect';
  static const String qrScannerVault = '/qr-scanner-vault';
  static const String questionVaultGenerator = '/question-vault-generator';
  static const String questionVaultManager = '/question-vault-manager';
  static const String staffAttendanceArchitect = '/staff-attendance-architect';
  static const String studentAttendanceArchitect = '/student-attendance-architect';
  static const String syllabusPage = '/syllabus-page';
  static const String testArchitect = '/test-architect';
  static const String studentQuiz = '/student-quiz';
  static const String contextualQuiz = '/contextual-quiz';

  // Owner Analytics Routes
  static const String analyticsScreen = '/analytics-screen';

  // Owner Timetable Routes
  static const String timetableDirectory = '/timetable-directory';

  // Owner Hub Tabs Routes
  static const String ownerHubAddUser = '/owner-hub-add-user';
  static const String ownerHubCall = '/owner-hub-call';
  static const String ownerHubChatProfile = '/owner-hub-chat-profile';
  static const String ownerHubChatList = '/owner-hub-chat-list';
  static const String ownerHubChatMessage = '/owner-hub-chat-message';
  static const String ownerHubChatVerification = '/owner-hub-chat-verification';
  static const String ownerHubUserRoles = '/owner-hub-user-roles';

  // Owner Profile Tabs Routes
  static const String activityLogs = '/activity-logs';
  static const String advancedSecurity = '/advanced-security';
  static const String blockedList = '/blocked-list';
  static const String institutionalTiming = '/institutional-timing';
  static const String institutionDirectory = '/institution-directory';
  static const String limitedAccess = '/limited-access';
  static const String personalInformation = '/personal-information';
  static const String professionalBio = '/professional-bio';
  static const String rolesList = '/roles-list';
  static const String settingsOverlay = '/settings-overlay';
  static const String verifyIdentities = '/verify-identities';
  static const String linkIdentities = '/link-identities';

  // Owner Tabs Routes
  static const String dashboardHomeTab = '/dashboard-home-tab';
  static const String dictionary = '/dictionary';
  static const String documentTranslator = '/document-translator';
  static const String facultyDirectory = '/faculty-directory';
  static const String sectionList = '/section-list';
  static const String staffDirectory = '/staff-directory';
  static const String staffHiring = '/staff-hiring';
  static const String students = '/students';
  static const String studentAdmission = '/student-admission';
  static const String teacherHiring = '/teacher-hiring';

  // Teacher Routes
  static const String teacherDashboard = '/teacher-dashboard';
  static const String teacherHub = '/teacher-hub';
  static const String teacherProfile = '/teacher-profile';
  static const String teacherPaper = '/teacher-paper';
  static const String teacherChatList = '/teacher-chat-list';
  static const String teacherChatMessage = '/teacher-chat-message';
  static const String teacherChatVerification = '/teacher-chat-verification';

  // Student Routes
  static const String studentDashboard = '/student-dashboard';
  static const String studentDoc = '/student-doc';
  static const String studentHub = '/student-hub';
  static const String studentProfile = '/student-profile';
  static const String studentChatList = '/student-chat-list';
  static const String studentChatMessage = '/student-chat-message';
  static const String studentChatVerification = '/student-chat-verification';
  static const String studentInbox = '/student-inbox';
  static const String studentChallenges = '/student-challenges';

  // Staff Routes
  static const String staffDashboard = '/staff-dashboard';
  static const String staffInstitutionSearch = '/staff-institution-search';
  static const String staffMain = '/staff-main';

  // Social Routes
  static const String socialPlatform = '/social';
  static const String explore = '/explore';
  static const String studentExplore = '/student-explore';
  static const String fullProfile = '/full-profile';

  // Hub Routes
  static const String wallet = '/wallet';

  // Mail Box Routes
  static const String inbox = '/inbox';
  static const String sent = '/sent';
  static const String compose = '/compose';

  // Store Routes
  static const String subscriptionStore = '/store';

  // Shop Routes
  static const String shop = '/shop';

  // AI Packages Routes
  static const String aiPackages = '/ai-packages';
  static const String booksmith = '/booksmith';
  static const String ttsConverter = '/tts-converter';
  static const String sideIde = '/side-ide';
  static const String studentsFeatures = '/students-features';

  // Chat System Routes
  static const String chatList = '/chat-list';
  static const String chatMessage = '/chat-message';
  static const String chatIds = '/chat-ids';
  static const String chatSearch = '/chat-search';
  static const String chatSettings = '/chat-settings';
  static const String chatSystemEntry = '/chat-system-entry';
  static const String chatAddUser = '/chat-add-user';
  static const String chatCall = '/chat-call';
  static const String chatProfile = '/chat-profile';
  static const String chatUserRoles = '/chat-user-roles';
  static const String chatVerification = '/chat-verification';
  static const String chatPrivacy = '/chat-privacy';
  static const String isolatedCall = '/isolated_call';
  static const String unifiedCall = '/unified_call';

  // QR Portal Routes
  static const String qrPortal = '/qr-portal';
  static const String qrScanner = '/qr-scanner';
  static const String qrResult = '/qr-result';
  static const String qrContentDisplay = '/qr-content-display';
  static const String qrCodeDisplay = '/qr-code-display';
  static const String qrLinkSearch = '/qr-link-search';
  static const String linkContentSearch = '/link-content-search';
  static const String contentDetail = '/content-detail';
  static const String createContent = '/create-content';
  static const String professionalContentList = '/professional-content-list';
  static const String qrAnalytics = '/qr-analytics';

  // Attendance & Assignments
  static const String attendance = '/attendance';
  static const String assignments = '/assignments';
  static const String grades = '/grades';
  static const String notices = '/notices';
  static const String events = '/events';
  static const String ingestionConsole = '/ingestion-console';
  static const String servicesManagement = '/services-management';
  static const String githubRepos = '/github-repos';
  static const String timetable = '/timetable';
  static const String fees = '/fees';
  static const String library = '/library';
  static const String reports = '/reports';
  static const String rtcLobby = '/rtc-lobby';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case languageSelection:
        return MaterialPageRoute(builder: (_) => const LanguageSelectionScreen());
      case intro:
        return MaterialPageRoute(builder: (_) => const IntroScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingOverlay());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case identityHub:
        return MaterialPageRoute(builder: (_) => const IdentityScreen());
      case phoneVerification:
        return MaterialPageRoute(builder: (_) => const PhoneVerificationScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case otpVerification:
        return MaterialPageRoute(builder: (_) => const OTPScreen(email: '', action: 'signup_verification'));
      case resetPassword:
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen(email: ''));
      case support:
        return MaterialPageRoute(builder: (_) => const SupportScreen());

      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());
      case ownerIdentity:
        return MaterialPageRoute(builder: (_) => const OwnerSetupScreen());
      case teacherIdentity:
        return MaterialPageRoute(builder: (_) => const TeacherSetupScreen());
      case studentIdentity:
        return MaterialPageRoute(builder: (_) => const StudentIdentitySetupScreen());
      case staffIdentity:
        return MaterialPageRoute(builder: (_) => const StaffIdentitySetupScreen());
      case parentIdentity:
        return MaterialPageRoute(builder: (_) => const ParentIdentitySetupScreen());
      case parentChildConnection:
        return MaterialPageRoute(builder: (_) => const ParentChildConnectionScreen());
      case parentConnection:
        return MaterialPageRoute(builder: (_) => const ParentConnectionScreen());
      case childConnection:
        return MaterialPageRoute(builder: (_) => const ChildConnectionScreen());
      case parentDashboard:
        return MaterialPageRoute(builder: (_) => const ParentDashboard());
      case institutionSetup:
        return MaterialPageRoute(builder: (_) => const InstitutionSetupScreen());
      case OwnershipCheckVerification:
        return MaterialPageRoute(builder: (_) => const OwnershipGateway());
      case identitySync:
        return MaterialPageRoute(builder: (_) => const IdentitySyncScreen());
      case staffSetup:
        return MaterialPageRoute(builder: (_) => const StaffSetupScreen());

      case dashboard:
        return MaterialPageRoute(builder: (_) => const MainEntryScreen());
      case institutionalDashboard:
        return MaterialPageRoute(builder: (_) => const HubDashboard());
      case ownerDashboard:
        return MaterialPageRoute(builder: (_) => const OwnerConsoleScreen());
      case ownerProfile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case ownerProfileScreen:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case ownerDocuments:
        return MaterialPageRoute(builder: (_) => const DocumentsScreen());
      case ownerDocumentVault:
        return MaterialPageRoute(builder: (_) => const DocumentVaultScreen());
      case ownerFinance:
        return MaterialPageRoute(builder: (_) => const FinanceScreen());
      case ownerStaffAccess:
        return MaterialPageRoute(builder: (_) => const StaffAccessControlScreen());
      case ownerConsole:
        return MaterialPageRoute(builder: (_) => const OwnerConsoleScreen());

      case advancedNotes:
        return MaterialPageRoute(builder: (_) => const AdvancedNotesScreen());
      case attendanceBlueprintVault:
        return MaterialPageRoute(builder: (_) => const AttendanceBlueprintVault());
      case blueprintEditor:
        return MaterialPageRoute(builder: (_) => const BlueprintEditor());
      case blueprintOverlay:
        return MaterialPageRoute(builder: (_) => BlueprintOverlay(isOpen: true, onClose: () {}));
      case datesheetArchitect:
        return MaterialPageRoute(builder: (_) => const DatesheetArchitect());
      case dictionaryPage:
        return MaterialPageRoute(builder: (_) => const DictionaryScreen());
      case documentHub:
        return MaterialPageRoute(builder: (_) => const DocumentHub());
      case documentScanner:
        return MaterialPageRoute(builder: (_) => DocumentScannerScreen());
      case documentStructuralScanner:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Document Structural Scanner - Coming Soon'))));
      case enhancedPaperScanner:
        return MaterialPageRoute(builder: (_) => const EnhancedPaperScanner());
      case feeVoucherDataEntry:
        return MaterialPageRoute(builder: (_) => const FeeVoucherDataEntry());
      case feeVoucherEditor:
        return MaterialPageRoute(builder: (_) => const FeeVoucherEditor());
      case marksheetPage:
        return MaterialPageRoute(builder: (_) => const MarksheetPage());
      case myFiles:
        return MaterialPageRoute(builder: (_) => MyFilesScreen());
      case noticeArchitect:
        return MaterialPageRoute(builder: (_) => const NoticeArchitect());
      case paperArchitect:
        return MaterialPageRoute(builder: (_) => const PaperArchitect());
      case paperScannerArchitect:
        return MaterialPageRoute(builder: (_) => const PaperScannerArchitect());
      case qrScannerVault:
        return MaterialPageRoute(builder: (_) => const QrScannerVault());
      case questionVaultGenerator:
        return MaterialPageRoute(builder: (_) => const QuestionVaultGenerator());
      case questionVaultManager:
        return MaterialPageRoute(builder: (_) => const QuestionVaultManager());
      case staffAttendanceArchitect:
        return MaterialPageRoute(builder: (_) => const StaffAttendanceArchitect());
      case studentAttendanceArchitect:
        return MaterialPageRoute(builder: (_) => const StudentAttendanceArchitect());
      case syllabusPage:
        return MaterialPageRoute(builder: (_) => const SyllabusPage());
      case testArchitect:
        return MaterialPageRoute(builder: (_) => const TestArchitect());
      case studentQuiz:
        return MaterialPageRoute(builder: (_) => const QuizPage());
      case contextualQuiz:
        return MaterialPageRoute(builder: (_) => const ContextualQuizScreen());

      case analyticsScreen:
        return MaterialPageRoute(builder: (_) => const AnalyticsScreen());

      case timetable:
      case timetableDirectory:
        return MaterialPageRoute(builder: (_) => const TimetableDirectory());

      case ownerHubAddUser:
        return MaterialPageRoute(builder: (_) => const AddUserScreen());
      case ownerHubCall:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Call - Use overlay system'))));
      case ownerHubChatProfile:
        return MaterialPageRoute(builder: (_) => const chat_system.WhatsAppChatEntry());
      case ownerHubChatList:
        return MaterialPageRoute(builder: (_) => const owner_hub.ChatListScreen());
      case ownerHubChatMessage:
        return MaterialPageRoute(builder: (_) => const owner_hub.ChatMessageScreen(userName: '', chatId: 0));
      case ownerHubChatVerification:
        return MaterialPageRoute(builder: (_) => const owner_hub.OwnerChatVerificationScreen());
      case ownerHubUserRoles:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('User Roles - Coming Soon'))));

      case activityLogs:
        return MaterialPageRoute(builder: (_) => ActivityLogsScreen(onClose: () {}));
      case advancedSecurity:
        return MaterialPageRoute(builder: (_) => AdvancedSecurityScreen(onClose: () {}));
      case blockedList:
        return MaterialPageRoute(builder: (_) => BlockedListScreen(onClose: () {}));
      case institutionalTiming:
        return MaterialPageRoute(builder: (_) => InstitutionalTimingScreen(onClose: () {}));
      case institutionDirectory:
        return MaterialPageRoute(builder: (_) => InstitutionDirectoryScreen(onBack: () {}));
      case limitedAccess:
        return MaterialPageRoute(builder: (_) => LimitedAccessScreen(onClose: () {}));
      case personalInformation:
        return MaterialPageRoute(builder: (_) => PersonalInformationScreen(onBack: () {}));
      case professionalBio:
        return MaterialPageRoute(builder: (_) => ProfessionalBioScreen(onBack: () {}));
      case rolesList:
        return MaterialPageRoute(builder: (_) => RolesListScreen(role: '', onClose: () {}));
      case settingsOverlay:
        return MaterialPageRoute(builder: (_) => SettingsScreen(onBack: () {}));
      case verifyIdentities:
        return MaterialPageRoute(builder: (_) => VerifyIdentitiesScreen(onClose: () {}));
      case linkIdentities:
        return MaterialPageRoute(builder: (_) => LinkIdentitiesScreen(onClose: () {}));

      case dashboardHomeTab:
        return MaterialPageRoute(builder: (_) => const DashboardHomeTab());
      case dictionary:
        return MaterialPageRoute(builder: (_) => const DictionaryScreen());
      case documentTranslator:
        return MaterialPageRoute(builder: (_) => const DocumentTranslator());
      case facultyDirectory:
        return MaterialPageRoute(builder: (_) => const FacultyDirectoryScreen());
      case sectionList:
        // TODO: SectionListScreen not found
        return MaterialPageRoute(builder: (_) => const Scaffold());
      case staffDirectory:
        return MaterialPageRoute(builder: (_) => const StaffDirectoryScreen());
      case staffHiring:
        return MaterialPageRoute(builder: (_) => const StaffHiringScreen());
      case students:
        return MaterialPageRoute(builder: (_) => const StudentListScreen(sectionName: 'All'));
      case studentAdmission:
        return MaterialPageRoute(builder: (_) => const StudentAdmissionScreen());
      case teacherHiring:
        return MaterialPageRoute(builder: (_) => const TeacherHiringScreen());

      case teacherDashboard:
        return MaterialPageRoute(builder: (_) => const MainTeacherScreen());
      case teacherHub:
        return MaterialPageRoute(builder: (_) => const TeacherHub());
      case teacherProfile:
        return MaterialPageRoute(builder: (_) => const TeacherProfile());
      case teacherPaper:
        return MaterialPageRoute(builder: (_) => const TeacherPaper());
      case teacherChatList:
        return MaterialPageRoute(builder: (_) => const TeacherChatListScreen());
      case teacherChatMessage:
        return MaterialPageRoute(builder: (_) => const TeacherChatMessageScreen(userName: '', chatId: 0));
      case teacherChatVerification:
        return MaterialPageRoute(builder: (_) => const TeacherChatVerificationScreen());

      case studentDashboard:
        return MaterialPageRoute(builder: (_) => const StudentDashboard());
      case studentDoc:
        return MaterialPageRoute(builder: (_) => const StudentDoc());
      case studentHub:
        return MaterialPageRoute(builder: (_) => const StudentHub());
      case studentProfile:
        return MaterialPageRoute(builder: (_) => const StudentProfile());
      case studentChatList:
        return MaterialPageRoute(builder: (_) => const StudentChatListScreen());
      case studentChatMessage:
        return MaterialPageRoute(builder: (_) => const ChatScreen(friendId: '', friendName: '', friendRole: ''));
      case studentChatVerification:
        return MaterialPageRoute(builder: (_) => const StudentChatVerificationScreen());

      case staffDashboard:
        return MaterialPageRoute(builder: (_) => const StaffDashboard());
      case staffInstitutionSearch:
        return MaterialPageRoute(builder: (_) => const StaffInstitutionSearchScreen());
      case staffMain:
        return MaterialPageRoute(builder: (_) => const StaffMainScreen());

      case socialPlatform:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialIndex = args?['initialIndex'] ?? 0;
        return MaterialPageRoute(builder: (_) => SocialMainScreen(initialIndex: initialIndex));
      case explore:
        final exploreArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ExplorePage(initialRole: exploreArgs?['initialRole'] ?? ''),
        );
      case studentExplore:
        return MaterialPageRoute(builder: (_) => const StudentExploreScreen());
      case studentChallenges:
        return MaterialPageRoute(builder: (_) => const SideChallengesScreen());
      case fullProfile:
        return MaterialPageRoute(builder: (_) => const FullProfileScreen(item: {}, isUser: true));

      case wallet:
        return MaterialPageRoute(builder: (_) => const WalletScreen());

      case inbox:
        return MaterialPageRoute(builder: (_) => const InboxScreen());
      case sent:
        return MaterialPageRoute(builder: (_) => const SentScreen());
      case compose:
        return MaterialPageRoute(builder: (_) => const ComposeScreen());

      case subscriptionStore:
        return MaterialPageRoute(builder: (_) => const SubscriptionStoreScreen());
      case shop:
        return MaterialPageRoute(builder: (_) => const ShopScreen());

      case aiPackages:
        return MaterialPageRoute(builder: (_) => const AIPackagesWidget());
      case booksmith:
        return MaterialPageRoute(builder: (_) => const BookSmithScreen());
      case ttsConverter:
        return MaterialPageRoute(builder: (_) => const TtsConverterScreen());
      case sideIde:
        return MaterialPageRoute(builder: (_) => const SideIdeScreen());
      case studentsFeatures:
        return MaterialPageRoute(builder: (_) => const StudentsFeaturesWidget());
      case studentInbox:
        return MaterialPageRoute(builder: (_) => const InboxScreen());
      case studentDashboard:
        return MaterialPageRoute(builder: (_) => const SocialMainScreen(initialIndex: 0));

      case chatList:
        return MaterialPageRoute(builder: (_) => const chat_system.WhatsAppChatEntry());
      case chatMessage:
        return MaterialPageRoute(builder: (_) => const ChatScreen(friendId: '', friendName: '', friendRole: ''));
      case chatIds:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Chat IDs - Coming Soon'))));
      case chatSearch:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Chat Search - Coming Soon'))));
      case chatSettings:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Chat Settings - Coming Soon'))));
      case chatSystemEntry:
        return MaterialPageRoute(builder: (_) => const chat_system.WhatsAppChatEntry());
      case chatAddUser:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Add User - Coming Soon'))));
      case chatCall:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Call - Coming Soon'))));
      case chatProfile:
        return MaterialPageRoute(builder: (_) => const ChatScreen(friendId: '', friendName: '', friendRole: ''));
      case chatUserRoles:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('User Roles - Coming Soon'))));
      case chatVerification:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Chat Verification - Coming Soon'))));
      case chatPrivacy:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Chat Privacy - Coming Soon'))));

      case isolatedCall:
        return MaterialPageRoute(builder: (_) => const IsolatedCallScreen());
      case unifiedCall:
        // UnifiedCallScreen requires a session parameter, so this route is only used internally
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Use UnifiedCallScreen with session parameter'))));

      case qrPortal:
        return MaterialPageRoute(builder: (_) => const QRPortalScreen());
      case qrScanner:
        return MaterialPageRoute(builder: (_) => const QRScannerScreen());
      case qrResult:
        return MaterialPageRoute(builder: (_) => QRResultScreen(qrLink: QRLinkModel(id: '', title: '', description: '', link: '', userId: '', createdAt: DateTime.now())));
      case qrContentDisplay:
        return MaterialPageRoute(builder: (_) => QRContentDisplayScreen(link: '', data: {}));
      case qrCodeDisplay:
        return MaterialPageRoute(builder: (_) => QRCodeDisplayScreen(content: ProfessionalContentModel(id: '', title: '', description: '', contentType: '', content: '', userId: '', createdAt: DateTime.now())));
      case qrLinkSearch:
        return MaterialPageRoute(builder: (_) => const QRLinkSearchScreen());
      case linkContentSearch:
        return MaterialPageRoute(builder: (_) => const LinkContentSearchScreen());
      case contentDetail:
        return MaterialPageRoute(builder: (_) => ContentDetailScreen(content: ProfessionalContentModel(id: '', title: '', description: '', contentType: '', content: '', userId: '', createdAt: DateTime.now())));
      case createContent:
        return MaterialPageRoute(builder: (_) => const CreateContentScreen());
      case professionalContentList:
        return MaterialPageRoute(builder: (_) => const ProfessionalContentListScreen());
      case qrAnalytics:
        return MaterialPageRoute(builder: (_) => const AnalyticsDashboard(qrLinks: [], contents: []));

      case ingestionConsole:
        return MaterialPageRoute(
          builder: (_) => const IngestionDashboardScreen(),
        );

      case servicesManagement:
        return MaterialPageRoute(
          builder: (_) => const ServicesManagementScreen(),
        );

      case githubRepos:
        return MaterialPageRoute(
          builder: (_) => const GithubReposScreen(),
        );

      case rtcLobby:
        final lobbyArgs = settings.arguments as Map<String, dynamic>?;
        final showInstitutional = lobbyArgs?['showInstitutional'] ?? true;
        return MaterialPageRoute(
          builder: (_) => RtcLobbyScreen(showInstitutionalTab: showInstitutional),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text("Route Error: ${settings.name} not found"),
            ),
          ),
        );
    }
  }
}
