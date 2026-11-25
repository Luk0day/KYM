import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/store.dart';
import '../../domain/usecases/watch_store_detail.dart';

enum StoreDetailStatus { loading, ready, notFound, error }

class StoreDetailController extends ChangeNotifier {
  StoreDetailController(this._watchStoreDetail);

  final WatchStoreDetail _watchStoreDetail;

  StoreDetailStatus _status = StoreDetailStatus.loading;
  Store? _store;
  String? _id;
  StreamSubscription<Store?>? _subscription;
  bool _disposed = false;

  StoreDetailStatus get status => _status;
  Store? get store => _store;

  /// Começa a observar a loja. Mesmo id de novo não faz nada.
  void load(String id) {
    if (_subscription != null && _id == id) return;
    _id = id;
    _subscribe();
  }

  void retry() {
    if (_id == null) return;
    _status = StoreDetailStatus.loading;
    _notify();
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _watchStoreDetail(_id!).listen(
      (store) {
        _store = store;
        _status = store == null
            ? StoreDetailStatus.notFound
            : StoreDetailStatus.ready;
        _notify();
      },
      onError: (Object _) {
        _status = StoreDetailStatus.error;
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
