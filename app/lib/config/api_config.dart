class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// 시연용 피보호자 계정 (DataInitializer)
  static const String demoPatientCode = '523891';

  static String wsUrl(String httpBase) {
    final uri = Uri.parse(httpBase);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.hasPort ? uri.port : (scheme == 'wss' ? 443 : 80);
    return '$scheme://${uri.host}:$port/ws-native';
  }

  static String formatLoginCode(String code) {
    final digits = code.replaceAll(RegExp(r'\s'), '');
    if (digits.length != 6) return code;
    return '${digits.substring(0, 3)} ${digits.substring(3)}';
  }
}
