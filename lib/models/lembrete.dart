import 'package:flutter/material.dart';

enum LembreteStatus {
  pendente('pendente'),
  concluido('concluido'),
  concluidoComFoto('concluido_com_foto'),
  adiado('adiado'),
  perdido('perdido'),
  confirmadoPeloCuidador('confirmado_pelo_cuidador');

  final String storageValue;
  const LembreteStatus(this.storageValue);

  bool get isConcluido =>
      this == LembreteStatus.concluido ||
      this == LembreteStatus.concluidoComFoto ||
      this == LembreteStatus.confirmadoPeloCuidador;

  static LembreteStatus fromStorage(String? value) {
    return LembreteStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => LembreteStatus.pendente,
    );
  }
}

class Lembrete {
  final String id;
  final String titulo;
  final int horarioHour;
  final int horarioMinute;
  final String categoria;
  final String? audioPath;
  final bool concluido;
  final bool concluidoComFoto;
  final DateTime criadoEm;
  final String? medicamentoForma;
  final String? medicamentoCor;
  final String? medicamentoFotoPath;
  final String? idosoId;
  final LembreteStatus status;
  final bool repeteTodosOsDias;
  final bool recorrenciaSemanal;
  final bool recorrenciaMensal;
  final bool recorrenciaIntervalo;
  final bool lembreteUnico;
  final List<int> diasSemana;
  final int? diaMes;
  final int? intervaloHoras;
  final String recorrencia;
  final String urgencia;

  Lembrete({
    required this.id,
    required this.titulo,
    required this.horarioHour,
    required this.horarioMinute,
    this.categoria = 'personalizado',
    this.audioPath,
    bool concluido = false,
    bool concluidoComFoto = false,
    DateTime? criadoEm,
    this.medicamentoForma,
    this.medicamentoCor,
    this.medicamentoFotoPath,
    this.idosoId,
    LembreteStatus? status,
    this.repeteTodosOsDias = true,
    this.recorrenciaSemanal = false,
    this.recorrenciaMensal = false,
    this.recorrenciaIntervalo = false,
    this.lembreteUnico = false,
    this.diasSemana = const [],
    this.diaMes,
    this.intervaloHoras,
    this.recorrencia = 'diario',
    this.urgencia = 'normal',
  }) : criadoEm = criadoEm ?? DateTime.now(),
       status =
           status ??
           (concluidoComFoto
               ? LembreteStatus.concluidoComFoto
               : concluido
               ? LembreteStatus.concluido
               : LembreteStatus.pendente),
       concluido = status?.isConcluido ?? concluidoComFoto || concluido,
       concluidoComFoto = status != null
           ? status == LembreteStatus.concluidoComFoto
           : concluidoComFoto;

  TimeOfDay get horario => TimeOfDay(hour: horarioHour, minute: horarioMinute);

  String get horarioFormatado {
    final h = horarioHour.toString().padLeft(2, '0');
    final m = horarioMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Lembrete copyWith({
    String? id,
    String? titulo,
    int? horarioHour,
    int? horarioMinute,
    String? categoria,
    String? audioPath,
    bool? concluido,
    bool? concluidoComFoto,
    DateTime? criadoEm,
    String? medicamentoForma,
    String? medicamentoCor,
    String? medicamentoFotoPath,
    String? idosoId,
    LembreteStatus? status,
    bool? repeteTodosOsDias,
    bool? recorrenciaSemanal,
    bool? recorrenciaMensal,
    bool? recorrenciaIntervalo,
    bool? lembreteUnico,
    List<int>? diasSemana,
    int? diaMes,
    int? intervaloHoras,
    String? recorrencia,
    String? urgencia,
  }) {
    final newStatus =
        status ??
        (concluidoComFoto == true
            ? LembreteStatus.concluidoComFoto
            : concluido == true
            ? LembreteStatus.concluido
            : concluido == false || concluidoComFoto == false
            ? LembreteStatus.pendente
            : this.status);
    return Lembrete(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      horarioHour: horarioHour ?? this.horarioHour,
      horarioMinute: horarioMinute ?? this.horarioMinute,
      categoria: categoria ?? this.categoria,
      audioPath: audioPath ?? this.audioPath,
      concluido: concluido ?? newStatus.isConcluido,
      concluidoComFoto:
          concluidoComFoto ?? newStatus == LembreteStatus.concluidoComFoto,
      criadoEm: criadoEm ?? this.criadoEm,
      medicamentoForma: medicamentoForma ?? this.medicamentoForma,
      medicamentoCor: medicamentoCor ?? this.medicamentoCor,
      medicamentoFotoPath: medicamentoFotoPath ?? this.medicamentoFotoPath,
      idosoId: idosoId ?? this.idosoId,
      status: newStatus,
      repeteTodosOsDias: repeteTodosOsDias ?? this.repeteTodosOsDias,
      recorrenciaSemanal: recorrenciaSemanal ?? this.recorrenciaSemanal,
      recorrenciaMensal: recorrenciaMensal ?? this.recorrenciaMensal,
      recorrenciaIntervalo: recorrenciaIntervalo ?? this.recorrenciaIntervalo,
      lembreteUnico: lembreteUnico ?? this.lembreteUnico,
      diasSemana: diasSemana ?? this.diasSemana,
      diaMes: diaMes ?? this.diaMes,
      intervaloHoras: intervaloHoras ?? this.intervaloHoras,
      recorrencia: recorrencia ?? this.recorrencia,
      urgencia: urgencia ?? this.urgencia,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'horarioHour': horarioHour,
    'horarioMinute': horarioMinute,
    'categoria': categoria,
    'audioPath': audioPath,
    'concluido': status.isConcluido,
    'concluidoComFoto': status == LembreteStatus.concluidoComFoto,
    'criadoEm': criadoEm.toIso8601String(),
    'medicamentoForma': medicamentoForma,
    'medicamentoCor': medicamentoCor,
    'medicamentoFotoPath': medicamentoFotoPath,
    'idosoId': idosoId,
    'status': status.storageValue,
    'repeteTodosOsDias': repeteTodosOsDias,
    'recorrenciaSemanal': recorrenciaSemanal,
    'recorrenciaMensal': recorrenciaMensal,
    'recorrenciaIntervalo': recorrenciaIntervalo,
    'lembreteUnico': lembreteUnico,
    'diasSemana': diasSemana,
    'diaMes': diaMes,
    'intervaloHoras': intervaloHoras,
    'recorrencia': recorrencia,
    'urgencia': urgencia,
  };

  factory Lembrete.fromJson(Map<String, dynamic> json) {
    final concluido = json['concluido'] as bool? ?? false;
    final concluidoComFoto = json['concluidoComFoto'] as bool? ?? false;
    return Lembrete(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      horarioHour: json['horarioHour'] as int,
      horarioMinute: json['horarioMinute'] as int,
      categoria: json['categoria'] as String? ?? 'personalizado',
      audioPath: json['audioPath'] as String?,
      concluido: concluido,
      concluidoComFoto: concluidoComFoto,
      criadoEm:
          DateTime.tryParse(json['criadoEm'] as String? ?? '') ??
          DateTime.now(),
      medicamentoForma: json['medicamentoForma'] as String?,
      medicamentoCor: json['medicamentoCor'] as String?,
      medicamentoFotoPath: json['medicamentoFotoPath'] as String?,
      idosoId: json['idosoId'] as String?,
      status: json['status'] != null
          ? LembreteStatus.fromStorage(json['status'] as String?)
          : concluidoComFoto
          ? LembreteStatus.concluidoComFoto
          : concluido
          ? LembreteStatus.concluido
          : LembreteStatus.pendente,
      repeteTodosOsDias: json['repeteTodosOsDias'] as bool? ?? true,
      recorrenciaSemanal: json['recorrenciaSemanal'] as bool? ?? false,
      recorrenciaMensal: json['recorrenciaMensal'] as bool? ?? false,
      recorrenciaIntervalo: json['recorrenciaIntervalo'] as bool? ?? false,
      lembreteUnico: json['lembreteUnico'] as bool? ?? false,
      diasSemana:
          (json['diasSemana'] as List?)?.map((item) => item as int).toList() ??
          const [],
      diaMes: json['diaMes'] as int?,
      intervaloHoras: json['intervaloHoras'] as int?,
      recorrencia: json['recorrencia'] as String? ?? 'diario',
      urgencia: json['urgencia'] as String? ?? 'normal',
    );
  }
}
