import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presenter/controllers/session_controller.dart';
import '../../domain/entities/store_filter.dart';
import '../../domain/entities/store_list_result.dart';
import '../../domain/services/sync_service.dart';
import '../../domain/usecases/refresh_stores.dart';
import '../../domain/usecases/watch_stores.dart';
import '../utils/stores_messages.dart';

enum StoresStatus { loading, ready, error }

class StoresController extends ChangeNotifier {
  StoresController(this._watchStores, this._refreshStores, this._session);

  static const Duration searchDebounce = Duration(milliseconds: 300);

  final WatchStores _watchStores;
  final RefreshStores _refreshStores;
  final SessionController _session;

  StoresStatus _status = StoresStatus.loading;
  StoreListResult _result = StoreListResult.empty;
  StoreFilter _filter = const StoreFilter();
  String? _syncMessage;
  bool _isRefreshing = false;
  bool _disposed = false;
  StreamSubscription<StoreListResult>? _subscription;
  Timer? _debounce;

  StoresStatus get status => _status;
  StoreListResult get result => _result;
  StoreFilter get filter => _filter;
  String? get syncMessage => _syncMessage;

  /// Só o gestor enxerga lojas inativas.
  bool get includeInactive => _session.user?.role == UserRole.gestor;

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
      _subscribe();
    });
  }

  void applyFilters({String? city, required bool onlyWithPending}) {
    _filter = _filter.copyWith(
      city: city,
      clearCity: city == null,
      onlyWithPending: onlyWithPending,
    );
    _subscribe();
  }

  void clearAll() {
    _debounce?.cancel();
    _filter = const StoreFilter();
    _subscribe();
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
      return true;
    } on SyncFailure catch (failure) {
      _syncMessage = failure.type.userMessage;
    } catch (_) {
      _syncMessage = SyncFailureType.unexpected.userMessage;
    } finally {
      _isRefreshing = false;
    }

    notifyListeners();
    return false;
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _watchStores(
      filter: _filter,
      includeInactive: includeInactive,
    ).listen(
      (result) {
        _result = result;
        _status = StoresStatus.ready;
        notifyListeners();
      },
      onError: (Object _) {
        _status = StoresStatus.error;
        notifyListeners();
      },
    );
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
