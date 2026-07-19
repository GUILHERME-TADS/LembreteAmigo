import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  Future<void>? _initialization;

  Future<void> _initialize() {
    if (kIsWeb) return Future.value();
    return _initialization ??= GoogleSignIn.instance.initialize();
  }

  Future<UserCredential> signIn() async {
    if (kIsWeb) {
      return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    }

    await _initialize();
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Erro ao obter credenciais do Google.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      return FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('cancel') || errStr.contains('abort') || errStr.contains('user')) {
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Login cancelado pelo usuário.',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _initialize();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // A sessao Firebase ainda deve ser encerrada mesmo sem sessao Google.
      }
    }
    await FirebaseAuth.instance.signOut();
  }
}
