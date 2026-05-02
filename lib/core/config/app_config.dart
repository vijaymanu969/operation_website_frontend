class AppConfig {
  AppConfig._();

  // Resolved at compile time. Default = local dev. For production builds
  // pass --dart-define=API_BASE_URL=https://operations.conveylabs.ai
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
      defaultValue: 'https://operations.conveylabs.ai',
  );

  // AI platform values are loaded from lib/.env at runtime via flutter_dotenv.
  // See AgentsScreen for usage. NOTE: anything in .env is still bundled into
  // the web build and visible to anyone who loads the app — for real secrecy,
  // proxy these calls through the operations backend.

  // Page names — must match what backend stores in ops_page_access
  static const pageTasks = 'tasks';
  static const pageAttendance = 'attendance';
  static const pageChat = 'chat';
  static const pageAnalytics = 'analytics';
  static const pageClients = 'clients';
  static const pageAgents = 'agents';
}
