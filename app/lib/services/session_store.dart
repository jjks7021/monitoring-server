import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionStore {
  static const _keyLoginCode = 'loginCode';
  static const _keyHardwareId = 'hardwareId';
  static const _keyUserName = 'userName';
  static const _keyRole = 'role';

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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoginCode, loginCode);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyRole, role);
    await getOrCreateHardwareId();
  }

  static Future<String?> loginCode() async =>
      (await SharedPreferences.getInstance()).getString(_keyLoginCode);

  static Future<String?> userName() async =>
      (await SharedPreferences.getInstance()).getString(_keyUserName);

  static Future<String?> role() async =>
      (await SharedPreferences.getInstance()).getString(_keyRole);
}
