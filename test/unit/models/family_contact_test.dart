import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/models/family_contact.dart';

void main() {
  group('FamilyContact Model Tests', () {
    test('instancia corretamente e gera map', () {
      const contact = FamilyContact(
        id: 'contact_1',
        nome: 'Maria Silva',
        parentesco: 'Filha',
        telefone: '11999998888',
        fotoUrl: '/path/to/foto.jpg',
        isPrincipal: true,
      );

      expect(contact.id, 'contact_1');
      expect(contact.nome, 'Maria Silva');
      expect(contact.parentesco, 'Filha');
      expect(contact.telefone, '11999998888');
      expect(contact.fotoUrl, '/path/to/foto.jpg');
      expect(contact.isPrincipal, isTrue);

      final map = contact.toMap();
      expect(map['id'], 'contact_1');
      expect(map['nome'], 'Maria Silva');
      expect(map['parentesco'], 'Filha');
      expect(map['telefone'], '11999998888');
      expect(map['isPrincipal'], isTrue);
    });

    test('fromMap cria objeto integro com defaults', () {
      final contact = FamilyContact.fromMap({
        'id': 'contact_2',
        'nome': 'Carlos',
        'parentesco': 'Filho',
        'telefone': '11977776666',
      });

      expect(contact.id, 'contact_2');
      expect(contact.nome, 'Carlos');
      expect(contact.parentesco, 'Filho');
      expect(contact.telefone, '11977776666');
      expect(contact.fotoUrl, isNull);
      expect(contact.isPrincipal, isFalse);
    });

    test('tituloExibicao formata nome e parentesco', () {
      const contact1 = FamilyContact(
        id: 'c1',
        nome: 'Ana',
        parentesco: 'Filha',
        telefone: '123',
      );
      expect(contact1.tituloExibicao, 'Ana (Filha)');

      const contact2 = FamilyContact(
        id: 'c2',
        nome: 'Carlos',
        parentesco: 'Família',
        telefone: '123',
      );
      expect(contact2.tituloExibicao, 'Carlos');
    });
  });
}
