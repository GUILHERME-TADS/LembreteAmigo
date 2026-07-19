class WidgetData {
  final String id;
  final String titulo;
  final int horarioHour;
  final int horarioMinute;
  final String categoria;
  final String status;
  WidgetData({
    required this.id,
    required this.titulo,
    required this.horarioHour,
    required this.horarioMinute,
    required this.categoria,
    required this.status,
  });

  String get horarioFormatado {
    final h = horarioHour.toString().padLeft(2, '0');
    final m = horarioMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get icone {
    switch (categoria) {
      case 'medicacao':
        return '\u{1F48A}';
      case 'refeicao':
      case 'refeicoes':
        return '\u{1F37D}';
      case 'exercicio':
        return '\u{1F3C3}';
      case 'agua':
      case 'hidratacao':
        return '\u{1F4A7}';
      case 'bem_estar':
        return '\u{1F60A}';
      default:
        return '\u{23F0}';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': titulo,
    'hour': horarioHour,
    'minute': horarioMinute,
    'category': categoria,
    'status': status,
    'priority': categoria == 'medicacao' ? 'alta' : 'normal',
  };

  factory WidgetData.fromJson(Map<String, dynamic> json) => WidgetData(
    id: json['id'] as String? ?? '',
    titulo: json['title'] as String? ?? '',
    horarioHour: (json['hour'] as num?)?.toInt() ?? 0,
    horarioMinute: (json['minute'] as num?)?.toInt() ?? 0,
    categoria: json['category'] as String? ?? 'personalizado',
    status: json['status'] as String? ?? 'proximo',
  );
}
