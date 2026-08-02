import 'package:firebase_core/firebase_core.dart';

class FirebaseHelper {
  static const bool isDemoRecording = bool.fromEnvironment(
    'DEMO_RECORDING',
    defaultValue: false,
  );

  static bool get isInitialized {
    if (isDemoRecording) return false;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
