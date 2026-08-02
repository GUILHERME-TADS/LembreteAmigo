import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/web_upload_helper.dart';

class MediaUploadService {
  /// Faz upload de um arquivo ou blob de mídia para o Firebase Storage.
  /// Retorna a URL pública de download do arquivo enviado.
  static Future<String> upload({
    required String localPath,
    required String destinationPath,
    required String contentType,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(destinationPath);
    await _ensureAuthBeforeUpload();

    if (kIsWeb) {
      try {
        final bytes = await fetchBlobBytes(localPath);
        if (bytes == null) {
          throw StateError(
            'Não foi possível obter bytes do blob no navegador.',
          );
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

  static Future<void> _ensureAuthBeforeUpload() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        throw StateError(
          'Authentication is required before uploading private media.',
        );
      }
    } catch (e) {
      debugPrint('Erro ao verificar autenticação antes do upload: $e');
      rethrow;
    }
  }
}
