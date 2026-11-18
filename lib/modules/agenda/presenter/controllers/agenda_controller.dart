import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/authenticated_user.dart';
import '../../../orders/domain/entities/agenda_item.dart';
import '../../../orders/domain/entities/order_situation.dart';
import '../../domain/entities/agenda_filter.dart';
import '../../domain/entities/agenda_section.dart';
import '../../domain/usecases/build_agenda.dart';
import '../../domain/usecases/watch_agenda.dart';

enum AgendaStatus { loading, ready, error }

class AgendaFilterMemory {
  final Map<String, AgendaFilter> _byUser = {};

  AgendaFilter? read(String userId) => _byUser[userId];

  void write(String userId, AgendaFilter filter) => _byUser[userId] = filter;
}

class AgendaController extends ChangeNotifier {
  AgendaController(
    this._watchAgenda,
    this._buildAgenda,
    this._memory,
    this.user, {
    this._clock = DateTime.now,
  }) {
    _filter = _memory.read(user.id) ?? AgendaFilter(start: today);
  }

  static const int stripDaysBefore = 7;
  static const int stripDaysAfter = 27;

  final WatchAgenda _watchAgenda;
  final BuildAgenda _buildAgenda;
  final AgendaFilterMemory _memory;
  final AuthenticatedUser user;
  final DateTime Function() _clock;

  late AgendaFilter _filter;
  StreamSubscription<List<AgendaItem>>? _subscription;
  List<AgendaItem> _items = const [];
  AgendaStatus _status = AgendaStatus.loading;
  bool _disposed = false;

  AgendaFilter get filter => _filter;
  AgendaStatus get status => _status;
  DateTime get today => dateOnly(_clock());

  List<AgendaSection> get sections =>
      _buildAgenda(items: _items, filter: _filter, today: _clock());

  AgendaSummary get summary =>
      _buildAgenda.summary(items: _items, today: _clock());

  /// Dias da faixa do topo: a semana anterior, a atual e as seguintes, a
  /// partir de uma segunda-feira, sempre incluindo o dia selecionado.
  List<DateTime> get stripDays {
    final anchor = _filter.start.isBefore(today) ? _filter.start : today;
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    final first = DateTime(
      monday.year,
      monday.month,
      monday.day - stripDaysBefore,
    );
    final count = stripDaysBefore + 7 + stripDaysAfter;
    return [
      for (var i = 0; i < count; i++)
        DateTime(first.year, first.month, first.day + i),
    ];
  }

  void start() {
    _subscription?.cancel();
    if (_status != AgendaStatus.loading) {
      _status = AgendaStatus.loading;
      _notify();
    }
    _subscription = _watchAgenda(userId: user.id, role: user.role).listen(
      (items) {
        _items = items;
        _status = AgendaStatus.ready;
        _notify();
      },
      onError: (Object _) {
        _status = AgendaStatus.error;
        _notify();
      },
    );
  }

  void selectSituation(AgendaSituationFilter situation) =>
      _update(_filter.copyWith(situation: situation));

  void selectPeriod(AgendaPeriod period) {
    if (period == AgendaPeriod.personalizado) return;
    _update(
      AgendaFilter(
        situation: _filter.situation,
        period: period,
        start: _filter.start,
      ),
    );
  }

  void selectRange(DateTime start, DateTime end) => _update(
    AgendaFilter(
      situation: _filter.situation,
      period: AgendaPeriod.personalizado,
      start: start,
      customEnd: end,
    ),
  );

  void selectDay(DateTime day) {
    final period = _filter.period == AgendaPeriod.personalizado
        ? AgendaPeriod.hoje
        : _filter.period;
    _update(
      AgendaFilter(situation: _filter.situation, period: period, start: day),
    );
  }

  void _update(AgendaFilter filter) {
    _filter = filter;
    _memory.write(user.id, filter);
    _notify();
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
