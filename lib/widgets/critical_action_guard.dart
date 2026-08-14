import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';

class CriticalActionGuard {
  const CriticalActionGuard._();

  static bool needsRecentLogin(DateTime? lastSignIn, DateTime now) {
    if (lastSignIn == null) return true;
    return now.difference(lastSignIn) > const Duration(minutes: 10);
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.security, color: AppColors.error, size: 42),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar com segurança'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return false;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return _typedConfirmation(context);
    }
    if (user == null || user.isAnonymous) {
      return _typedConfirmation(context);
    }
    if (!needsRecentLogin(user.metadata.lastSignInTime, DateTime.now())) {
      return true;
    }

    final passwordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    try {
      if (passwordProvider && user.email != null) {
        final password = await _requestPassword(context);
        if (password == null || password.isEmpty) return false;
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      } else if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        await GoogleSignIn.instance.initialize();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          throw FirebaseAuthException(
            code: 'canceled',
            message: 'Confirmação de identidade cancelada.',
          );
        }
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      return true;
    } on FirebaseAuthException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'wrong-password' ||
                      error.code == 'invalid-credential'
                  ? 'Senha incorreta. A ação foi cancelada.'
                  : 'Não foi possível confirmar sua identidade.',
            ),
          ),
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _requestPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirme sua senha'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Senha atual'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  static Future<bool> _typedConfirmation(BuildContext context) async {
    final controller = TextEditingController();
    var enabled = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirmação final'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Digite REMOVER para confirmar.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) => setDialogState(
                  () => enabled = value.trim().toUpperCase() == 'REMOVER',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: enabled
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Remover vínculo'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result == true;
  }
}
