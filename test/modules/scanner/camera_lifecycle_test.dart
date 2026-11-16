import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/scanner/presenter/controllers/camera_lifecycle.dart';

void main() {
  late CameraLifecycle lifecycle;

  setUp(() => lifecycle = CameraLifecycle());

  test('câmera rodando para em segundo plano e volta ao retornar', () {
    expect(lifecycle.onBackground(isRunning: true), isTrue);
    expect(lifecycle.onForeground(active: true), isTrue);
  });

  test('só volta uma vez por ida a segundo plano', () {
    lifecycle.onBackground(isRunning: true);
    lifecycle.onForeground(active: true);

    expect(lifecycle.onForeground(active: true), isFalse);
  });

  test('câmera que ainda não iniciou não é parada nem religada', () {
    // Diálogo de permissão: o app fica inativo antes de a câmera iniciar.
    expect(lifecycle.onBackground(isRunning: false), isFalse);
    expect(lifecycle.onForeground(active: true), isFalse);
  });

  test('não religa quando um código está em tratamento', () {
    lifecycle.onBackground(isRunning: true);

    expect(lifecycle.onForeground(active: false), isFalse);
  });

  test('volta das configurações tenta iniciar de novo', () {
    lifecycle.markAwaitingSettings();

    expect(lifecycle.onForeground(active: true), isTrue);
    expect(lifecycle.onForeground(active: true), isFalse);
  });

  test('volta das configurações com código em tratamento não inicia', () {
    lifecycle.markAwaitingSettings();

    expect(lifecycle.onForeground(active: false), isFalse);
  });
}
