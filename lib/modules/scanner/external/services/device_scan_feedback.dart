import 'package:flutter/services.dart';

import '../../domain/services/scan_feedback.dart';

class DeviceScanFeedback implements ScanFeedback {
  @override
  Future<void> confirm() => HapticFeedback.vibrate();
}
