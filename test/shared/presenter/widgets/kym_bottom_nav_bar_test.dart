import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/theme/app_colors.dart';
import 'package:kym/app/theme/app_theme.dart';
import 'package:kym/shared/presenter/widgets/kym_bottom_nav_bar.dart';
import 'package:kym/shared/presenter/widgets/kym_button.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: const SizedBox.expand(), bottomNavigationBar: child),
  );
}

const _items = [
  KymNavItem(icon: Icons.grid_view_outlined, label: 'Painel'),
  KymNavItem(
    icon: Icons.qr_code_2,
    label: 'Escanear',
    tooltip: 'Escanear QR Code',
    prominent: true,
    badge: 'QR',
  ),
  KymNavItem(icon: Icons.person_outline, label: 'Perfil'),
];

void main() {
  group('KymBottomNavBar', () {
    testWidgets('mostra rótulos e avisa o índice tocado', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        _wrap(
          KymBottomNavBar(
            items: _items,
            selectedIndex: 0,
            onSelected: taps.add,
          ),
        ),
      );

      expect(find.text('Painel'), findsOneWidget);
      expect(find.text('Escanear'), findsOneWidget);
      expect(find.text('QR'), findsOneWidget);

      await tester.tap(find.text('Perfil'));
      await tester.tap(find.byTooltip('Escanear QR Code'));

      expect(taps, [2, 1]);
    });

    testWidgets('destino selecionado usa a cor primária', (tester) async {
      await tester.pumpWidget(
        _wrap(
          KymBottomNavBar(items: _items, selectedIndex: 2, onSelected: (_) {}),
        ),
      );

      Color? iconColor(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color;

      expect(iconColor(Icons.person_outline), AppColors.primary);
      expect(iconColor(Icons.grid_view_outlined), AppColors.textSecondary);
    });

    testWidgets('expõe semântica de botão selecionado', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          KymBottomNavBar(items: _items, selectedIndex: 0, onSelected: (_) {}),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Painel')),
        isSemantics(
          label: 'Painel',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Escanear QR Code')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  group('KymButton soft', () {
    testWidgets('usa fundo laranja claro e texto laranja', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: KymButton(
              label: 'Sair da conta',
              variant: KymButtonVariant.soft,
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final style = button.style!;
      expect(style.backgroundColor!.resolve({}), AppColors.overdueBg);
      expect(style.foregroundColor!.resolve({}), AppColors.accent);

      await tester.tap(find.text('Sair da conta'));
      expect(taps, 1);
    });
  });
}
