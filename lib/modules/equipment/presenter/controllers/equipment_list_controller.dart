import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/equipment_list_item.dart';
import '../../domain/usecases/watch_store_equipment.dart';

enum EquipmentListStatus { loading, ready, error }

/// Equipamentos de uma loja, lidos do banco local (B27).
class EquipmentListController extends ChangeNotifier {
  EquipmentListController(this._watchStoreEquipment);

  final WatchStoreEquipment _watchStoreEquipment;

  EquipmentListStatus _status = EquipmentListStatus.loading;
  List<EquipmentListItem> _items = const [];
  String? _storeId;
  StreamSubscription<List<EquipmentListItem>>? _subscription;
  bool _disposed = false;

  EquipmentListStatus get status => _status;
  List<EquipmentListItem> get items => _items;

  /// Começa a observar a loja. Mesma loja de novo não faz nada.
  void load(String storeId) {
    if (_subscription != null && _storeId == storeId) return;
    _storeId = storeId;
    _subscribe();
  }

  void retry() {
    if (_storeId == null) return;
    _status = EquipmentListStatus.loading;
    _notify();
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _watchStoreEquipment(_storeId!).listen(
      (items) {
        _items = items;
        _status = EquipmentListStatus.ready;
        _notify();
      },
      onError: (Object _) {
        _status = EquipmentListStatus.error;
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
