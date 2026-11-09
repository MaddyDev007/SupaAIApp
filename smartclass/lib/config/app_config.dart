/// Centralized backend URL configuration.
///
/// Override for development or staging builds with:
/// flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8000
class AppConfig {
  AppConfig._();

  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://supaaiapp-1.onrender.com',
  );
}
