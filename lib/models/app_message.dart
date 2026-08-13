class AppMessage {
  final String id;
  final String idosoId;
  final String nomeIdoso;
  final String senderRole;
  final String tipo;
  final String texto;
  final String? audioPath;
  final DateTime criadoEm;
  final bool lido;
  final int? duracaoSegundos;

  const AppMessage({
    required this.id,
    required this.idosoId,
    required this.nomeIdoso,
    required this.senderRole,
    required this.tipo,
    required this.texto,
    this.audioPath,
    required this.criadoEm,
    this.lido = false,
    this.duracaoSegundos,
  });

  AppMessage copyWith({String? audioPath, bool? lido, String? texto}) {
    return AppMessage(
      id: id,
      idosoId: idosoId,
      nomeIdoso: nomeIdoso,
      senderRole: senderRole,
      tipo: tipo,
      texto: texto ?? this.texto,
      audioPath: audioPath ?? this.audioPath,
      criadoEm: criadoEm,
      lido: lido ?? this.lido,
      duracaoSegundos: duracaoSegundos,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'idosoId': idosoId,
    'nomeIdoso': nomeIdoso,
    'senderRole': senderRole,
    'tipo': tipo,
    'texto': texto,
    'audioPath': audioPath,
    'criadoEm': criadoEm.toIso8601String(),
    'lido': lido,
    'duracaoSegundos': duracaoSegundos,
  };

  factory AppMessage.fromJson(Map<String, dynamic> json) {
    return AppMessage(
      id:
          json['id'] as String? ??
          'msg_${DateTime.now().microsecondsSinceEpoch}',
      idosoId: json['idosoId'] as String? ?? 'idoso_local',
      nomeIdoso: json['nomeIdoso'] as String? ?? 'Idoso',
      senderRole: json['senderRole'] as String? ?? 'elderly',
      tipo: json['tipo'] as String? ?? 'texto',
      texto: json['texto'] as String? ?? '',
      audioPath: json['audioPath'] as String?,
      criadoEm:
          DateTime.tryParse(json['criadoEm'] as String? ?? '') ??
          DateTime.now(),
      lido: json['lido'] as bool? ?? false,
      duracaoSegundos: json['duracaoSegundos'] as int?,
    );
  }
}
