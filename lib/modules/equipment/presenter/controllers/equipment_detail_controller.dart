import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/equipment_detail.dart';
import '../../domain/usecases/watch_equipment_detail.dart';

enum EquipmentDetailStatus { loading, ready, notFound, error }

class EquipmentDetailController extends ChangeNotifier {
  EquipmentDetailController(this._watchEquipmentDetail);

  final WatchEquipmentDetail _watchEquipmentDetail;

  EquipmentDetailStatus _status = EquipmentDetailStatus.loading;
  EquipmentDetail? _detail;
  String? _id;
  StreamSubscription<EquipmentDetail?>? _subscription;
  bool _showAllHistory = false;
  bool _disposed = false;

  EquipmentDetailStatus get status => _status;
  EquipmentDetail? get detail => _detail;
  bool get showAllHistory => _showAllHistory;

  void load(String id) {
    if (_subscription != null && _id == id) return;
    _id = id;
    _subscribe();
  }

  void retry() {
    if (_id == null) return;
    _status = EquipmentDetailStatus.loading;
    _notify();
    _subscribe();
  }

  /// Alterna entre as últimas ordens e o histórico completo.
  void toggleHistory() {
    _showAllHistory = !_showAllHistory;
    _notify();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _watchEquipmentDetail(_id!).listen(
      (detail) {
        _detail = detail;
        _status = detail == null
            ? EquipmentDetailStatus.notFound
            : EquipmentDetailStatus.ready;
        _notify();
      },
      onError: (Object _) {
        _status = EquipmentDetailStatus.error;
        _notify();
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
