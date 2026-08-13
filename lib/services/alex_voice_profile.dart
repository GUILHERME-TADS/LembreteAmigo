import 'package:shared_preferences/shared_preferences.dart';
import 'session_role_service.dart';
import 'offline_sync_service.dart';
import '../utils/firebase_helper.dart';

class AlexVoiceProfile {
  final double speechRate;
  final double pitch;

  const AlexVoiceProfile({this.speechRate = 0.4, this.pitch = 1.0});

  AlexVoiceProfile copyWith({double? speechRate, double? pitch}) {
    return AlexVoiceProfile(
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
    );
  }

  static const _keyRate = 'alex_voice_rate';
  static const _keyPitch = 'alex_voice_pitch';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRate, speechRate);
    await prefs.setDouble(_keyPitch, pitch);

    if (FirebaseHelper.isInitialized) {
      final idosoId = await SessionRoleService.getActiveIdosoId();
      if (!SessionRoleService.isLocalOnlyIdosoId(idosoId) &&
          await SessionRoleService.canSyncElderlyPrivateData()) {
        await OfflineSyncService.instance.setOrQueue('idoso_perfil', idosoId, {
          'alex_voice_rate': speechRate,
          'alex_voice_pitch': pitch,
        });
        await OfflineSyncService.instance.setOrQueue('idosos', idosoId, {
          'alex_voice_rate': speechRate,
          'alex_voice_pitch': pitch,
        });
      }
    }
  }

  static Future<AlexVoiceProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rate = prefs.getDouble(_keyRate) ?? 0.4;
    final pitch = prefs.getDouble(_keyPitch) ?? 1.0;
    return AlexVoiceProfile(
      speechRate: rate.clamp(0.2, 1.0),
      pitch: pitch.clamp(0.5, 2.0),
    );
  }
}
