import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/scanner/domain/services/app_settings_service.dart';
import 'package:kym/modules/scanner/domain/usecases/open_app_settings.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettings extends Mock implements AppSettingsService {}

void main() {
  late _MockSettings service;
  late OpenAppSettings useCase;

  setUp(() {
    service = _MockSettings();
    useCase = OpenAppSettings(service);
  });

  test('devolve true quando as configurações abrem', () async {
    when(() => service.open()).thenAnswer((_) async => true);

    expect(await useCase(), isTrue);
  });

  test('devolve false quando o sistema não abre', () async {
    when(() => service.open()).thenAnswer((_) async => false);

    expect(await useCase(), isFalse);
  });

  test('erro do serviço vira false', () async {
    when(() => service.open()).thenThrow(Exception('falhou'));

    expect(await useCase(), isFalse);
  });
}
