import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/scanner/external/services/device_scan_feedback.dart';
import 'package:kym/modules/scanner/external/services/permission_handler_app_settings_service.dart';
import 'package:kym/modules/scanner/infra/services/pending_scanned_code_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DeviceScanFeedback pede a vibração ao sistema', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await DeviceScanFeedback().confirm();

    expect(calls, ['HapticFeedback.vibrate']);
  });

  test('PermissionHandlerAppSettingsService repassa o resultado', () async {
    var opened = 0;
    final service = PermissionHandlerAppSettingsService(
      opener: () async {
        opened++;
        return true;
      },
    );

    expect(await service.open(), isTrue);
    expect(opened, 1);
  });

  test('PendingScannedCodeHandler aceita qualquer texto', () async {
    await expectLater(PendingScannedCodeHandler().handle('abc'), completes);
  });
}
