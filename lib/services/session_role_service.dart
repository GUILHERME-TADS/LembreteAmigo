import 'package:shared_preferences/shared_preferences.dart';

class SessionRoleService {
  static const String _roleKey = 'active_user_role';
  static const String elderly = 'elderly';
  static const String supervisor = 'supervisor';

  static String? _activeRole;

  static String? get activeRole => _activeRole;
  static bool get isSupervisor => _activeRole == supervisor;
  static bool get isElderly => _activeRole == elderly;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _activeRole = prefs.getString(_roleKey);
  }

  static Future<void> setElderly() => _setRole(elderly);

  static Future<void> setSupervisor() => _setRole(supervisor);

  static Future<void> _setRole(String role) async {
    _activeRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }
}
