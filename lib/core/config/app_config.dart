class AppConfig {
  AppConfig._();

  // Resolved at compile time. Default = local dev. For production builds
  // pass --dart-define=API_BASE_URL=https://operations.conveylabs.ai
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
      defaultValue: 'https://operations.conveylabs.ai',
  );

  // AI agent platform — used by the Test Call Cards page.
  // Override with --dart-define=AI_PLATFORM_BASE_URL=https://your-host
  static const aiPlatformBaseUrl = String.fromEnvironment(
    'AI_PLATFORM_BASE_URL',
    defaultValue: 'https://api.conveylabs.ai',
  );

  // Page names — must match what backend stores in ops_page_access
  static const pageTasks = 'tasks';
  static const pageAttendance = 'attendance';
  static const pageChat = 'chat';
  static const pageAnalytics = 'analytics';
  static const pageClients = 'clients';
  static const pageAgents = 'agents';
}
