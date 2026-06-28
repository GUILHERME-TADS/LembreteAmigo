import 'package:flutter/material.dart';

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

  Lembrete({
    required this.id,
    required this.titulo,
    required this.horarioHour,
    required this.horarioMinute,
    this.categoria = 'personalizado',
    this.audioPath,
    this.concluido = false,
    this.concluidoComFoto = false,
    DateTime? criadoEm,
    this.medicamentoForma,
    this.medicamentoCor,
    this.medicamentoFotoPath,
    this.idosoId,
  }) : criadoEm = criadoEm ?? DateTime.now();

  TimeOfDay get horario => TimeOfDay(hour: horarioHour, minute: horarioMinute);

  String get horarioFormatado {
    final h = horarioHour.toString().padLeft(2, '0');
    final m = horarioMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'horarioHour': horarioHour,
    'horarioMinute': horarioMinute,
    'categoria': categoria,
    'audioPath': audioPath,
    'concluido': concluido,
    'concluidoComFoto': concluidoComFoto,
    'criadoEm': criadoEm.toIso8601String(),
    'medicamentoForma': medicamentoForma,
    'medicamentoCor': medicamentoCor,
    'medicamentoFotoPath': medicamentoFotoPath,
    'idosoId': idosoId,
  };

  factory Lembrete.fromJson(Map<String, dynamic> json) => Lembrete(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    horarioHour: json['horarioHour'] as int,
    horarioMinute: json['horarioMinute'] as int,
    categoria: json['categoria'] as String? ?? 'personalizado',
    audioPath: json['audioPath'] as String?,
    concluido: json['concluido'] as bool? ?? false,
    concluidoComFoto: json['concluidoComFoto'] as bool? ?? false,
    criadoEm: DateTime.parse(json['criadoEm'] as String),
    medicamentoForma: json['medicamentoForma'] as String?,
    medicamentoCor: json['medicamentoCor'] as String?,
    medicamentoFotoPath: json['medicamentoFotoPath'] as String?,
    idosoId: json['idosoId'] as String?,
  );
}

