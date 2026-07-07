import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String titulo;
  final String descricao;
  final String icone;
  final String tipo;
  final DateTime? dataDesbloqueio;
  final double progresso;
  final double progressoMaximo;

  const Achievement({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.tipo,
    this.dataDesbloqueio,
    this.progresso = 0,
    this.progressoMaximo = 1,
  });

  bool get desbloqueado => dataDesbloqueio != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'descricao': descricao,
        'icone': icone,
        'tipo': tipo,
        'dataDesbloqueio':
            dataDesbloqueio?.toIso8601String(),
        'progresso': progresso,
        'progressoMaximo': progressoMaximo,
      };

  factory Achievement.fromMap(Map<String, dynamic> map) => Achievement(
        id: map['id'] as String? ?? '',
        titulo: map['titulo'] as String? ?? '',
        descricao: map['descricao'] as String? ?? '',
        icone: map['icone'] as String? ?? '',
        tipo: map['tipo'] as String? ?? '',
        dataDesbloqueio: map['dataDesbloqueio'] != null
            ? DateTime.tryParse(map['dataDesbloqueio'] as String)
            : null,
        progresso: (map['progresso'] as num?)?.toDouble() ?? 0,
        progressoMaximo:
            (map['progressoMaximo'] as num?)?.toDouble() ?? 1,
      );

  factory Achievement.fromFirestore(
          DocumentSnapshot doc) =>
      Achievement.fromMap(doc.data() as Map<String, dynamic>);

  Achievement copyWith({
    String? id,
    String? titulo,
    String? descricao,
    String? icone,
    String? tipo,
    DateTime? dataDesbloqueio,
    double? progresso,
    double? progressoMaximo,
    bool clearDate = false,
  }) =>
      Achievement(
        id: id ?? this.id,
        titulo: titulo ?? this.titulo,
        descricao: descricao ?? this.descricao,
        icone: icone ?? this.icone,
        tipo: tipo ?? this.tipo,
        dataDesbloqueio: clearDate
            ? null
            : (dataDesbloqueio ?? this.dataDesbloqueio),
        progresso: progresso ?? this.progresso,
        progressoMaximo: progressoMaximo ?? this.progressoMaximo,
      );

  static List<Achievement> get allDefinitions => [
        Achievement(
          id: 'primeiro_passo',
          titulo: 'Primeiro Passo',
          descricao: 'Completou o primeiro lembrete!',
          icone: '🌟',
          tipo: 'streak',
          progressoMaximo: 1,
        ),
        Achievement(
          id: 'semana_de_ouro',
          titulo: 'Semana de Ouro',
          descricao: '7 dias seguidos de lembretes concluídos',
          icone: '🏅',
          tipo: 'streak',
          progressoMaximo: 7,
        ),
        Achievement(
          id: 'mes_dedicado',
          titulo: 'Mês Dedicado',
          descricao: '30 dias de compromisso com a saúde',
          icone: '🎖️',
          tipo: 'streak',
          progressoMaximo: 30,
        ),
        Achievement(
          id: 'foco_total',
          titulo: 'Foco Total',
          descricao:
              'Todos os lembretes feitos no horário por 7 dias',
          icone: '🎯',
          tipo: 'accuracy',
          progressoMaximo: 7,
        ),
        Achievement(
          id: 'heroi_da_familia',
          titulo: 'Herói da Família',
          descricao:
              'Idoso e familiar completaram o dia juntos',
          icone: '👨‍👩‍👧‍👦',
          tipo: 'family',
          progressoMaximo: 1,
        ),
        Achievement(
          id: 'mestre_remedios',
          titulo: 'Mestre dos Remédios',
          descricao: '100 medicações confirmadas',
          icone: '💊',
          tipo: 'total',
          progressoMaximo: 100,
        ),
      ];
}
