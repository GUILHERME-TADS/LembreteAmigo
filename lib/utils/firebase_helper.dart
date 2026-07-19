import 'package:firebase_core/firebase_core.dart';

class FirebaseHelper {
  static bool get isInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
