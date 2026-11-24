import 'package:flutter/widgets.dart';

/// Avisa a tela aberta quando o usuário toca de novo na aba dela, para que ela
/// se atualize no lugar em vez de abrir uma nova transição.
class TabReselect extends ChangeNotifier {
  void reselect() => notifyListeners();
}

class TabReselectScope extends InheritedWidget {
  const TabReselectScope({
    super.key,
    required this.notifier,
    required super.child,
  });

  final TabReselect notifier;

  static TabReselect? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabReselectScope>()?.notifier;

  @override
  bool updateShouldNotify(TabReselectScope oldWidget) =>
      notifier != oldWidget.notifier;
}
