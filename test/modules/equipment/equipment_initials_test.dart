import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/equipment/presenter/utils/equipment_messages.dart';

void main() {
  group('equipmentInitials', () {
    test('usa o prefixo do código de série', () {
      expect(equipmentInitials('AC-0012', 'Ar-condicionado Split'), 'AC');
      expect(equipmentInitials('fr-0003', 'Freezer vertical 03'), 'FR');
      expect(equipmentInitials('CX-0001', 'Câmara fria'), 'CX');
    });

    test('sem série usa as duas primeiras letras do nome', () {
      expect(equipmentInitials(null, 'Freezer'), 'FR');
      expect(equipmentInitials('', 'iluminação'), 'IL');
      expect(equipmentInitials('  ', 'X'), 'X');
    });

    test('série que não começa com letras cai no nome', () {
      expect(equipmentInitials('0012', 'Câmara fria'), 'CÂ');
    });

    test('nome e série vazios devolvem vazio', () {
      expect(equipmentInitials(null, ' '), '');
    });
  });
}
