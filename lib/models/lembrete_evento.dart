import 'lembrete.dart';

class LembreteEvento {
  final String id;
  final String lembreteId;
  final String titulo;
  final String categoria;
  final LembreteStatus status;
  final DateTime registradoEm;
  final String? idosoId;
  final String? observacao;

  LembreteEvento({
    required this.id,
    required this.lembreteId,
    required this.titulo,
    required this.categoria,
    required this.status,
    DateTime? registradoEm,
    this.idosoId,
    this.observacao,
  }) : registradoEm = registradoEm ?? DateTime.now();

  factory LembreteEvento.fromLembrete(
    Lembrete lembrete, {
    required LembreteStatus status,
    String? observacao,
  }) {
    final now = DateTime.now();
    return LembreteEvento(
      id: '${lembrete.id}_${now.millisecondsSinceEpoch}',
      lembreteId: lembrete.id,
      titulo: lembrete.titulo,
      categoria: lembrete.categoria,
      status: status,
      registradoEm: now,
      idosoId: lembrete.idosoId,
      observacao: observacao,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lembreteId': lembreteId,
    'titulo': titulo,
    'categoria': categoria,
    'status': status.storageValue,
    'registradoEm': registradoEm.toIso8601String(),
    'idosoId': idosoId,
    'observacao': observacao,
  };

  factory LembreteEvento.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        json['status'] as String? ?? LembreteStatus.pendente.storageValue;
    final status = LembreteStatus.values.firstWhere(
      (item) => item.storageValue == rawStatus,
      orElse: () => LembreteStatus.pendente,
    );

    return LembreteEvento(
      id: json['id'] as String,
      lembreteId: json['lembreteId'] as String,
      titulo: json['titulo'] as String? ?? 'Lembrete',
      categoria: json['categoria'] as String? ?? 'personalizado',
      status: status,
      registradoEm:
          DateTime.tryParse(json['registradoEm'] as String? ?? '') ??
          DateTime.now(),
      idosoId: json['idosoId'] as String?,
      observacao: json['observacao'] as String?,
    );
  }
}
