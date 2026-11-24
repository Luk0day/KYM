import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/presenter/controllers/session_controller.dart';
import '../../domain/entities/store_filter.dart';
import '../../domain/entities/store_list_result.dart';
import '../../domain/entities/store_summary.dart';
import '../../domain/services/sync_service.dart';
import '../../domain/usecases/filter_stores.dart';
import '../../domain/usecases/refresh_stores.dart';
import '../../domain/usecases/watch_stores.dart';
import '../utils/stores_messages.dart';

enum StoresStatus { loading, ready, error }

/// Estado da sincronização mostrado no selo do topo da tela. Começa em
/// [unknown] (selo escondido): a tela não sabe se os dados locais estão em dia
/// até uma sincronização terminar.
enum SyncIndicator { unknown, synced, offline, failed }

class StoresController extends ChangeNotifier {
  StoresController(
    this._watchStores,
    this._filterStores,
    this._refreshStores,
    this._session,
  );

  static const Duration searchDebounce = Duration(milliseconds: 300);

  final WatchStores _watchStores;
  final FilterStores _filterStores;
  final RefreshStores _refreshStores;
  final SessionController _session;

  StoresStatus _status = StoresStatus.loading;
  List<StoreSummary> _visible = const [];
  StoreListResult _result = StoreListResult.empty;
  StoreFilter _filter = const StoreFilter();
  SyncIndicator _syncIndicator = SyncIndicator.unknown;
  String? _syncMessage;
  bool _isRefreshing = false;
  bool _disposed = false;
  StreamSubscription<List<StoreSummary>>? _subscription;
  Timer? _debounce;

  StoresStatus get status => _status;
  StoreListResult get result => _result;
  StoreFilter get filter => _filter;
  SyncIndicator get syncIndicator => _syncIndicator;
  String? get syncMessage => _syncMessage;

  /// Começa a observar o banco local. Chamar de novo não faz nada.
  void load() {
    if (_subscription != null) {
      return;
    }
    _subscribe();
  }

  void retry() {
    _status = StoresStatus.loading;
    notifyListeners();
    _subscribe();
  }

  /// A busca espera [searchDebounce] sem digitação antes de filtrar.
  void setQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      _filter = _filter.copyWith(query: query);
      _applyFilter();
    });
  }

  void selectKind(StoreFilterKind kind) {
    if (kind == _filter.kind) {
      return;
    }
    _filter = _filter.copyWith(kind: kind);
    _applyFilter();
  }

  void clearAll() {
    _debounce?.cancel();
    _filter = const StoreFilter();
    _applyFilter();
  }

  /// Retorna `false` se a sincronização falhou; o motivo fica em [syncMessage].
  Future<bool> refresh() async {
    if (_isRefreshing) {
      return true;
    }
    _isRefreshing = true;
    _syncMessage = null;

    try {
      await _refreshStores();
      _syncIndicator = SyncIndicator.synced;
      notifyListeners();
      return true;
    } on SyncFailure catch (failure) {
      _syncMessage = failure.type.userMessage;
      _syncIndicator = failure.type == SyncFailureType.offline
          ? SyncIndicator.offline
          : SyncIndicator.failed;
    } catch (_) {
      _syncMessage = SyncFailureType.unexpected.userMessage;
      _syncIndicator = SyncIndicator.failed;
    } finally {
      _isRefreshing = false;
    }

    notifyListeners();
    return false;
  }

  /// Assina o banco uma vez só; a busca e as abas filtram em memória.
  void _subscribe() {
    _subscription?.cancel();
    _subscription = _watchStores(role: _session.user?.role).listen(
      (stores) {
        _visible = stores;
        _status = StoresStatus.ready;
        _applyFilter();
      },
      onError: (Object _) {
        _status = StoresStatus.error;
        notifyListeners();
      },
    );
  }

  void _applyFilter() {
    _result = _filterStores(_visible, _filter);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
