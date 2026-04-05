class AppConfig {
  AppConfig._();

  static const baseUrl = 'http://localhost:3001';

  // Page names — must match what backend stores in ops_page_access
  static const pageTasks = 'tasks';
  static const pageAttendance = 'attendance';
  static const pageChat = 'chat';
  static const pageAnalytics = 'analytics';
  static const pageClients = 'clients';
}
