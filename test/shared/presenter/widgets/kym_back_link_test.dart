import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/shared/presenter/widgets/kym_back_link.dart';

void main() {
  testWidgets('KymBackLink mostra o rótulo e chama onPressed', (t) async {
    var voltou = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KymBackLink(label: 'Lojas', onPressed: () => voltou = true),
        ),
      ),
    );

    expect(find.text('Lojas'), findsOneWidget);
    await t.tap(find.text('Lojas'));
    expect(voltou, isTrue);
  });

  testWidgets('KymBackLink tem rótulo semântico e área de toque de 48 dp', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KymBackLink(label: 'Lojas', onPressed: () {}),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Voltar para Lojas'), findsOneWidget);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(t, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
