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
  final String? ocorrenciaChave;
  final String? metodoConfirmacao;
  final String? corrigeEventoId;
  final String? atorPapel;
  final int? estoqueAnterior;
  final double? unidadesConsumidas;
  final int? estoqueRestante;
  final int? estoqueRestaurado;
  final String? fotoConfirmacaoPath;

  LembreteEvento({
    required this.id,
    required this.lembreteId,
    required this.titulo,
    required this.categoria,
    required this.status,
    DateTime? registradoEm,
    this.idosoId,
    this.observacao,
    this.ocorrenciaChave,
    this.metodoConfirmacao,
    this.corrigeEventoId,
    this.atorPapel,
    this.estoqueAnterior,
    this.unidadesConsumidas,
    this.estoqueRestante,
    this.estoqueRestaurado,
    this.fotoConfirmacaoPath,
  }) : registradoEm = registradoEm ?? DateTime.now();

  factory LembreteEvento.fromLembrete(
    Lembrete lembrete, {
    required LembreteStatus status,
    String? observacao,
    String? ocorrenciaChave,
    String? metodoConfirmacao,
    String? corrigeEventoId,
    String? atorPapel,
    int? estoqueAnterior,
    double? unidadesConsumidas,
    int? estoqueRestante,
    int? estoqueRestaurado,
    String? fotoConfirmacaoPath,
    String? eventId,
  }) {
    final now = DateTime.now();
    return LembreteEvento(
      id: eventId ?? '${lembrete.id}_${now.millisecondsSinceEpoch}',
      lembreteId: lembrete.id,
      titulo: lembrete.titulo,
      categoria: lembrete.categoria,
      status: status,
      registradoEm: now,
      idosoId: lembrete.idosoId,
      observacao: observacao,
      ocorrenciaChave: ocorrenciaChave,
      metodoConfirmacao: metodoConfirmacao,
      corrigeEventoId: corrigeEventoId,
      atorPapel: atorPapel,
      estoqueAnterior: estoqueAnterior,
      unidadesConsumidas: unidadesConsumidas,
      estoqueRestante: estoqueRestante,
      estoqueRestaurado: estoqueRestaurado,
      fotoConfirmacaoPath: fotoConfirmacaoPath,
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
    'ocorrenciaChave': ocorrenciaChave,
    'metodoConfirmacao': metodoConfirmacao,
    'corrigeEventoId': corrigeEventoId,
    'atorPapel': atorPapel,
    'estoqueAnterior': estoqueAnterior,
    'unidadesConsumidas': unidadesConsumidas,
    'estoqueRestante': estoqueRestante,
    'estoqueRestaurado': estoqueRestaurado,
    'fotoConfirmacaoPath': fotoConfirmacaoPath,
  };

  factory LembreteEvento.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        json['status'] as String? ?? LembreteStatus.pendente.storageValue;
    final status = LembreteStatus.values.firstWhere(
      (item) => item.storageValue == rawStatus,
      orElse: () => LembreteStatus.pendente,
    );

    return LembreteEvento(
      id: json['id'] as String? ?? '',
      lembreteId: json['lembreteId'] as String? ?? '',
      titulo: json['titulo'] as String? ?? 'Lembrete',
      categoria: json['categoria'] as String? ?? 'personalizado',
      status: status,
      registradoEm:
          DateTime.tryParse(json['registradoEm'] as String? ?? '') ??
          DateTime.now(),
      idosoId: json['idosoId'] as String?,
      observacao: json['observacao'] as String?,
      ocorrenciaChave: json['ocorrenciaChave'] as String?,
      metodoConfirmacao: json['metodoConfirmacao'] as String?,
      corrigeEventoId: json['corrigeEventoId'] as String?,
      atorPapel: json['atorPapel'] as String?,
      estoqueAnterior: (json['estoqueAnterior'] as num?)?.toInt(),
      unidadesConsumidas: (json['unidadesConsumidas'] as num?)?.toDouble(),
      estoqueRestante: (json['estoqueRestante'] as num?)?.toInt(),
      estoqueRestaurado: (json['estoqueRestaurado'] as num?)?.toInt(),
      fotoConfirmacaoPath: json['fotoConfirmacaoPath'] as String?,
    );
  }
}
