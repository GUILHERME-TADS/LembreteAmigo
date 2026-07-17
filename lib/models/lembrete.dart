import 'package:flutter/material.dart';

enum LembreteStatus {
  pendente('pendente'),
  concluido('concluido'),
  concluidoComFoto('concluido_com_foto'),
  adiado('adiado'),
  perdido('perdido'),
  precisaDeAjuda('precisa_de_ajuda'),
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
  final int? originalHorarioHour;
  final int? originalHorarioMinute;
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
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool isUsoContinuo;
  final String? medicamentoInstrucoes;
  final String? medicamentoAudioTexto;

  Lembrete({
    required this.id,
    required this.titulo,
    required this.horarioHour,
    required this.horarioMinute,
    int? originalHorarioHour,
    int? originalHorarioMinute,
    this.categoria = 'personalizado',
    this.dataInicio,
    this.dataFim,
    this.isUsoContinuo = true,
    this.audioPath,
    this.medicamentoInstrucoes,
    this.medicamentoAudioTexto,
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
  }) : criadoEm = criadoEm ?? DateTime.now(),
       originalHorarioHour = originalHorarioHour ?? horarioHour,
       originalHorarioMinute = originalHorarioMinute ?? horarioMinute,
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
    int? originalHorarioHour,
    int? originalHorarioMinute,
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
    DateTime? dataInicio,
    DateTime? dataFim,
    bool? isUsoContinuo,
    String? medicamentoInstrucoes,
    String? medicamentoAudioTexto,
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
      originalHorarioHour: originalHorarioHour ?? this.originalHorarioHour,
      originalHorarioMinute:
          originalHorarioMinute ?? this.originalHorarioMinute,
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
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      isUsoContinuo: isUsoContinuo ?? this.isUsoContinuo,
      medicamentoInstrucoes:
          medicamentoInstrucoes ?? this.medicamentoInstrucoes,
      medicamentoAudioTexto:
          medicamentoAudioTexto ?? this.medicamentoAudioTexto,
    );
  }

  bool isActiveOn(DateTime date) => isReminderActiveOn(this, date);

  static bool isReminderActiveOn(Lembrete lembrete, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (lembrete.dataInicio != null) {
      final startOnly = DateTime(
        lembrete.dataInicio!.year,
        lembrete.dataInicio!.month,
        lembrete.dataInicio!.day,
      );
      if (dateOnly.isBefore(startOnly)) return false;
    }

    if (lembrete.isUsoContinuo == false && lembrete.dataFim != null) {
      final endOnly = DateTime(
        lembrete.dataFim!.year,
        lembrete.dataFim!.month,
        lembrete.dataFim!.day,
      );
      if (dateOnly.isAfter(endOnly)) return false;
    }

    if (lembrete.recorrencia == 'unico' || lembrete.lembreteUnico) {
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final targetDate = lembrete.dataInicio ?? lembrete.criadoEm;
      final targetKey =
          '${targetDate.year}-${targetDate.month}-${targetDate.day}';
      return dateKey == targetKey;
    }
    if (lembrete.recorrencia == 'semanal' || lembrete.recorrenciaSemanal) {
      return lembrete.diasSemana.contains(date.weekday);
    }
    if (lembrete.recorrencia == 'mensal' || lembrete.recorrenciaMensal) {
      return (lembrete.diaMes ?? lembrete.criadoEm.day) == date.day;
    }
    if (lembrete.recorrencia == 'quinzenal') {
      final baseDate = lembrete.dataInicio ?? lembrete.criadoEm;
      final diffDays = DateTime(date.year, date.month, date.day)
          .difference(DateTime(baseDate.year, baseDate.month, baseDate.day))
          .inDays;
      return diffDays >= 0 && diffDays % 15 == 0;
    }
    if (lembrete.recorrencia == 'intervalo' || lembrete.recorrenciaIntervalo) {
      return true;
    }
    if (lembrete.recorrencia == 'diario' || lembrete.repeteTodosOsDias) {
      return true;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'horarioHour': horarioHour,
    'horarioMinute': horarioMinute,
    'originalHorarioHour': originalHorarioHour,
    'originalHorarioMinute': originalHorarioMinute,
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
    'dataInicio': dataInicio?.toIso8601String(),
    'dataFim': dataFim?.toIso8601String(),
    'isUsoContinuo': isUsoContinuo,
    'medicamentoInstrucoes': medicamentoInstrucoes,
    'medicamentoAudioTexto': medicamentoAudioTexto,
  };

  factory Lembrete.fromJson(Map<String, dynamic> json) {
    final concluido = json['concluido'] as bool? ?? false;
    final concluidoComFoto = json['concluidoComFoto'] as bool? ?? false;
    final hHour = (json['horarioHour'] as num?)?.toInt() ?? 0;
    final hMinute = (json['horarioMinute'] as num?)?.toInt() ?? 0;
    return Lembrete(
      id: json['id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      horarioHour: hHour,
      horarioMinute: hMinute,
      originalHorarioHour:
          (json['originalHorarioHour'] as num?)?.toInt() ?? hHour,
      originalHorarioMinute:
          (json['originalHorarioMinute'] as num?)?.toInt() ?? hMinute,
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
          (json['diasSemana'] as List?)
              ?.map((item) => (item as num?)?.toInt() ?? 0)
              .toList() ??
          const [],
      diaMes: (json['diaMes'] as num?)?.toInt(),
      intervaloHoras: (json['intervaloHoras'] as num?)?.toInt(),
      recorrencia: json['recorrencia'] as String? ?? 'diario',
      dataInicio: json['dataInicio'] != null
          ? DateTime.tryParse(json['dataInicio'] as String)
          : null,
      dataFim: json['dataFim'] != null
          ? DateTime.tryParse(json['dataFim'] as String)
          : null,
      isUsoContinuo: json['isUsoContinuo'] as bool? ?? true,
      medicamentoInstrucoes: json['medicamentoInstrucoes'] as String?,
      medicamentoAudioTexto: json['medicamentoAudioTexto'] as String?,
    );
  }
}
