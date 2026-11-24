import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/scanner/presenter/widgets/scan_frame.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

void main() {
  testWidgets('com animate, a linha de leitura anima', (tester) async {
    await tester.pumpWidget(_wrap(const ScanFrame(size: 240)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('com animate falso, a linha fica parada', (tester) async {
    await tester.pumpWidget(_wrap(const ScanFrame(size: 240, animate: false)));

    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('com animações do sistema desligadas, a linha fica parada', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ScanFrame(size: 240), disableAnimations: true),
    );

    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('para e retoma a linha quando animate muda', (tester) async {
    await tester.pumpWidget(_wrap(const ScanFrame(size: 240)));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_wrap(const ScanFrame(size: 240, animate: false)));
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_wrap(const ScanFrame(size: 240)));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('ocupa o tamanho pedido e fica fora da semântica', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ScanFrame(size: 200, animate: false)));

    expect(tester.getSize(find.byType(ScanFrame)), const Size(200, 200));
    expect(find.byType(ExcludeSemantics), findsWidgets);
  });
}
