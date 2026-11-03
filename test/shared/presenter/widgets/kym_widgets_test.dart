import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/theme/app_theme.dart';
import 'package:kym/shared/presenter/widgets/kym_banner.dart';
import 'package:kym/shared/presenter/widgets/kym_brand_logo.dart';
import 'package:kym/shared/presenter/widgets/kym_button.dart';
import 'package:kym/shared/presenter/widgets/kym_chip.dart';
import 'package:kym/shared/presenter/widgets/kym_text_field.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('KymButton', () {
    testWidgets('primário chama onPressed ao tocar', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(KymButton(label: 'Entrar', onPressed: () => taps++)),
      );

      await tester.tap(find.byType(FilledButton));

      expect(taps, 1);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('carregando mostra spinner e ignora toques', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          KymButton(label: 'Entrar', onPressed: () => taps++, isLoading: true),
        ),
      );

      await tester.tap(find.byType(FilledButton), warnIfMissed: false);

      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
    });

    testWidgets('cada variante usa o botão do Material correspondente',
        (tester) async {
      Future<void> pumpVariant(KymButtonVariant variant) {
        return tester.pumpWidget(
          _wrap(KymButton(label: 'Ação', onPressed: () {}, variant: variant)),
        );
      }

      await pumpVariant(KymButtonVariant.secondary);
      expect(find.byType(OutlinedButton), findsOneWidget);

      await pumpVariant(KymButtonVariant.tertiary);
      expect(find.byType(TextButton), findsOneWidget);

      await pumpVariant(KymButtonVariant.destructive);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('mostra o conteúdo à esquerda do rótulo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          KymButton(
            label: 'Continuar',
            onPressed: () {},
            leading: const Icon(Icons.star_rounded),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
    });
  });

  group('KymTextField', () {
    testWidgets('mostra rótulo e dica', (tester) async {
      await tester.pumpWidget(
        _wrap(const KymTextField(label: 'E-mail', hintText: 'seu@email.com')),
      );

      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('seu@email.com'), findsOneWidget);
    });

    testWidgets('exibe a mensagem do validador', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: KymTextField(
              label: 'Senha',
              validator: (_) => 'Informe sua senha.',
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('Informe sua senha.'), findsOneWidget);
    });
  });

  group('KymBanner', () {
    testWidgets('erro mostra a mensagem e o ícone de erro', (tester) async {
      await tester.pumpWidget(_wrap(const KymBanner(message: 'Algo falhou.')));

      expect(find.text('Algo falhou.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('sucesso mostra o ícone de check', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KymBanner(message: 'Salvo.', type: KymBannerType.success),
        ),
      );

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });
  });

  testWidgets('KymChip escreve o rótulo em maiúsculas', (tester) async {
    await tester.pumpWidget(
      _wrap(const KymChip(label: 'Preventiva', tone: KymChipTone.pending)),
    );

    expect(find.text('PREVENTIVA'), findsOneWidget);
  });

  testWidgets('KymBrandLogo mostra marca e subtítulo', (tester) async {
    await tester.pumpWidget(_wrap(const KymBrandLogo()));

    expect(find.text('KYM'), findsOneWidget);
    expect(find.text('Know Your Maintenance'), findsOneWidget);
  });
}
