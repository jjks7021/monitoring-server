import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionStore {
  static const _keyLoginCode = 'loginCode';
  static const _keyHardwareId = 'hardwareId';
  static const _keyUserName = 'userName';
  static const _keyRole = 'role';
  static const _keyIsGuardian = 'isGuardian';

  static Future<String> getOrCreateHardwareId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyHardwareId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_keyHardwareId, id);
    }
    return id;
  }

  static Future<void> saveSession({
    required String loginCode,
    required String userName,
    required String role,
    bool isGuardian = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoginCode, loginCode);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyRole, role);
    await prefs.setBool(_keyIsGuardian, isGuardian);
    await getOrCreateHardwareId();
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoginCode);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyIsGuardian);
    // 로그아웃 시 기기 ID도 초기화 → 다음 연결 시 서버에서 새 랜덤 코드 발급
    await prefs.remove(_keyHardwareId);
  }

  static Future<bool> hasSession() async {
    final code = await loginCode();
    return code != null && code.isNotEmpty;
  }

  static Future<String?> loginCode() async =>
      (await SharedPreferences.getInstance()).getString(_keyLoginCode);

  static Future<String?> userName() async =>
      (await SharedPreferences.getInstance()).getString(_keyUserName);

  static Future<String?> role() async =>
      (await SharedPreferences.getInstance()).getString(_keyRole);

  static Future<bool> isGuardian() async =>
      (await SharedPreferences.getInstance()).getBool(_keyIsGuardian) ?? false;
}
