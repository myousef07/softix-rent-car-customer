/// Build-time settings, one build per rental company:
/// flutter build apk --dart-define=API_BASE_URL=https://rent.example.sa/api/v1 \
///   --dart-define=COMPANY_ID=12 --dart-define=COMPANY_NAME="شركة المثال لتأجير السيارات"
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const companyId = int.fromEnvironment('COMPANY_ID', defaultValue: 1);

  static const companyName = String.fromEnvironment('COMPANY_NAME', defaultValue: 'SOftiX لتأجير السيارات');

  /// Saudi Arabia keeps UTC+3 all year; the API sends and expects UTC.
  static const riyadhOffset = Duration(hours: 3);
}
