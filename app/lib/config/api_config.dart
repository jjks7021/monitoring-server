import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// `--dart-define=API_BASE_URL=...` 가 있으면 우선 사용.
  /// 없으면 Android → 에뮬레이터 호스트(10.0.2.2), 그 외 → localhost.
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  static String wsUrl(String httpBase) {
    final uri = Uri.parse(httpBase);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    // ngrok URL은 명시적 포트가 없으므로 host만 사용 (표준 443/80 포트 자동 적용)
    final hostWithPort = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    return '$scheme://$hostWithPort/ws-native';
  }

  static String formatLoginCode(String code) {
    final digits = code.replaceAll(RegExp(r'\s'), '');
    if (digits.length != 6) return code;
    return '${digits.substring(0, 3)} ${digits.substring(3)}';
  }
}
