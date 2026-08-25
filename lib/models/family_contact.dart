/// Modelo de dados para contatos favoritos da família no discador rápido do idoso.
class FamilyContact {
  final String id;
  final String nome;
  final String parentesco;
  final String telefone;
  final String? fotoUrl;
  final bool isPrincipal;

  const FamilyContact({
    required this.id,
    required this.nome,
    required this.parentesco,
    required this.telefone,
    this.fotoUrl,
    this.isPrincipal = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'parentesco': parentesco,
      'telefone': telefone,
      'fotoUrl': fotoUrl,
      'isPrincipal': isPrincipal,
    };
  }

  factory FamilyContact.fromMap(Map<String, dynamic> map) {
    return FamilyContact(
      id: map['id'] as String? ?? '',
      nome: map['nome'] as String? ?? 'Familiar',
      parentesco: map['parentesco'] as String? ?? 'Família',
      telefone: map['telefone'] as String? ?? '',
      fotoUrl: map['fotoUrl'] as String?,
      isPrincipal: map['isPrincipal'] as bool? ?? false,
    );
  }

  /// Retorna o título formatado com nome e parentesco (ex: "Ana (Filha)")
  String get tituloExibicao {
    if (parentesco.isNotEmpty && parentesco.toLowerCase() != 'família') {
      return '$nome ($parentesco)';
    }
    return nome;
  }
}
