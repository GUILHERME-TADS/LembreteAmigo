import 'package:shared_preferences/shared_preferences.dart';

class SessionRoleService {
  static const String _roleKey = 'active_user_role';
  static const String elderly = 'elderly';
  static const String supervisor = 'supervisor';
  static const String unpairedIdosoId = 'idoso_sem_vinculo';

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

  static Future<String> getActiveIdosoId({
    String fallback = unpairedIdosoId,
  }) async {
    if (_activeRole == null) {
      await load();
    }

    final prefs = await SharedPreferences.getInstance();
    final supervisorActive = prefs.getString('selected_idoso_id');
    final elderlyActive = prefs.getString('paired_idoso_id');

    if (isElderly) {
      return elderlyActive ?? supervisorActive ?? fallback;
    }
    if (isSupervisor) {
      return supervisorActive ?? elderlyActive ?? fallback;
    }
    return supervisorActive ?? elderlyActive ?? fallback;
  }

  static Future<String?> getActiveIdosoIdOrNull() async {
    final idosoId = await getActiveIdosoId(fallback: '');
    return idosoId.isEmpty ? null : idosoId;
  }

  static Future<void> _setRole(String role) async {
    _activeRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }
}
