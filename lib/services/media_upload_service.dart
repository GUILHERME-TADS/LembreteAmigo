import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/web_upload_helper.dart';
import 'session_role_service.dart';

class MediaUploadService {
  /// Faz upload de um arquivo ou blob de mídia para o Firebase Storage.
  /// Retorna a URL pública de download do arquivo enviado.
  static Future<String> upload({
    required String localPath,
    required String destinationPath,
    required String contentType,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(destinationPath);
    await _ensurePreflightAuthAndSupervisor(destinationPath);

    if (kIsWeb) {
      try {
        final bytes = await fetchBlobBytes(localPath);
        if (bytes == null) {
          throw StateError('Não foi possível obter bytes do blob no navegador.');
        }
        final snapshot = await ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        debugPrint('Erro no upload de mídia via Web: $e');
        rethrow;
      }
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('Arquivo local para upload não encontrado: $localPath');
    }

    try {
      final snapshot = await ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Erro no upload de mídia nativa para $destinationPath: $e');
      rethrow;
    }
  }

  static Future<void> _ensurePreflightAuthAndSupervisor(String destinationPath) async {
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = await SessionRoleService.ensureElderlyAuthSession();
        user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      }
      if (user != null) {
        final parts = destinationPath.split('/');
        final targetId = parts.length >= 2 ? parts[1] : '';
        debugPrint('=== [UPLOAD PREFLIGHT] Target: $destinationPath | Auth UID: ${user.uid} | targetId: $targetId | Role Elder: ${SessionRoleService.isElderly} | Role Sup: ${SessionRoleService.isSupervisor} ===');
        if (targetId.isNotEmpty && !SessionRoleService.isLocalOnlyIdosoId(targetId) && targetId != user.uid) {
          await SessionRoleService.ensureSupervisorDocAndSubcollection(user.uid, targetId);
        }
      }
    } catch (e) {
      debugPrint('Erro na verificação preflight antes do upload: $e');
    }
  }
}
