import 'dart:convert';

import '../models/emergency_card.dart';
import 'lembrete_service.dart';
import 'secure_cache_service.dart';

class EmergencyCardService {
  EmergencyCardService._();
  static final EmergencyCardService instance = EmergencyCardService._();

  static const _cacheKey = 'emergency_card_v1';

  Future<EmergencyCard> load() async {
    final raw = await SecureCacheService.instance.read(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return EmergencyCard.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {}
    }

    var name = '';
    var phone = '';
    final profileRaw = await SecureCacheService.instance.readElderlyProfile();
    if (profileRaw != null) {
      try {
        final profile = Map<String, dynamic>.from(
          jsonDecode(profileRaw) as Map,
        );
        name = profile['nome'] as String? ?? '';
        phone =
            profile['ambulancia_telefone'] as String? ??
            profile['telefone'] as String? ??
            '';
      } catch (_) {}
    }
    await LembreteService.instance.carregar();
    final medications = LembreteService.instance.lembretes
        .where((item) => item.categoria == 'medicacao')
        .map((item) => item.titulo)
        .where((title) => title.trim().isNotEmpty)
        .toSet()
        .take(10)
        .toList(growable: false);
    return EmergencyCard(
      name: name,
      allergies: '',
      medications: medications,
      contactName: 'Contato de emergência',
      contactPhone: phone,
      note: '',
      updatedAt: DateTime.now(),
    );
  }

  Future<void> save(EmergencyCard card) {
    return SecureCacheService.instance.write(
      _cacheKey,
      jsonEncode(card.toJson()),
    );
  }

  String qrPayload(EmergencyCard card) => jsonEncode(card.toQrJson());

  String shareText(EmergencyCard card) {
    final medications = card.medications.isEmpty
        ? 'Não informados'
        : card.medications.join(', ');
    return [
      'CARTÃO DE EMERGÊNCIA — LEMBRETE AMIGO',
      'Nome: ${card.name}',
      'Alergias: ${card.allergies.isEmpty ? 'Não informadas' : card.allergies}',
      'Medicamentos: $medications',
      'Contato: ${card.contactName} — ${card.contactPhone}',
      if (card.note.isNotEmpty) 'Observação: ${card.note}',
    ].join('\n');
  }
}
