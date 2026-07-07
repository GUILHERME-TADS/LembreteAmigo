import 'package:shared_preferences/shared_preferences.dart';

enum AlexVoiceGender { female, male }

class AlexVoiceProfile {
  final AlexVoiceGender gender;
  final double speechRate;
  final double pitch;

  const AlexVoiceProfile({
    this.gender = AlexVoiceGender.female,
    this.speechRate = 0.4,
    this.pitch = 1.0,
  });

  AlexVoiceProfile copyWith({
    AlexVoiceGender? gender,
    double? speechRate,
    double? pitch,
  }) {
    return AlexVoiceProfile(
      gender: gender ?? this.gender,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
    );
  }

  static const _keyGender = 'alex_voice_gender';
  static const _keyRate = 'alex_voice_rate';
  static const _keyPitch = 'alex_voice_pitch';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, gender.name);
    await prefs.setDouble(_keyRate, speechRate);
    await prefs.setDouble(_keyPitch, pitch);
  }

  static Future<AlexVoiceProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final genderStr = prefs.getString(_keyGender) ?? 'female';
    final rate = prefs.getDouble(_keyRate) ?? 0.4;
    final pitch = prefs.getDouble(_keyPitch) ?? 1.0;
    return AlexVoiceProfile(
      gender: genderStr == 'male' ? AlexVoiceGender.male : AlexVoiceGender.female,
      speechRate: rate.clamp(0.2, 1.0),
      pitch: pitch.clamp(0.5, 2.0),
    );
  }
}
