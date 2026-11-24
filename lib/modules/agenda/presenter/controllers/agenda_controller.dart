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

typedef SavedAgendaFilter = ({AgendaFilter filter, DateTime savedOn});

class AgendaFilterMemory {
  final Map<String, SavedAgendaFilter> _byUser = {};

  SavedAgendaFilter? read(String userId) => _byUser[userId];

  void write(String userId, AgendaFilter filter, DateTime savedOn) =>
      _byUser[userId] = (filter: filter, savedOn: dateOnly(savedOn));
}

class AgendaController extends ChangeNotifier {
  AgendaController(
    this._watchAgenda,
    this._buildAgenda,
    this._memory,
    this.user, {
    this._clock = DateTime.now,
  }) {
    final saved = _memory.read(user.id);
    _filter = saved?.filter ?? AgendaFilter(start: today);
    _filterDay = saved?.savedOn ?? today;
  }

  static const int stripDaysBefore = 7;
  static const int stripDaysAfter = 27;

  final WatchAgenda _watchAgenda;
  final BuildAgenda _buildAgenda;
  final AgendaFilterMemory _memory;
  final AuthenticatedUser user;
  final DateTime Function() _clock;

  late AgendaFilter _filter;
  late DateTime _filterDay;
  StreamSubscription<List<AgendaItem>>? _subscription;
  List<AgendaItem> _items = const [];
  AgendaStatus _status = AgendaStatus.loading;
  bool _disposed = false;

  AgendaFilter get filter {
    final today = this.today;
    if (_filterDay != today) {
      _filter = _carriedTo(_filter, today);
      _filterDay = today;
    }
    return _filter;
  }

  AgendaStatus get status => _status;
  DateTime get today => dateOnly(_clock());

  List<AgendaSection> get sections =>
      _buildAgenda(items: _items, filter: filter, today: _clock());

  AgendaSummary get summary =>
      _buildAgenda.summary(items: _items, today: _clock());

  /// Dias da faixa do topo: a semana anterior, a atual e as seguintes, a
  /// partir de uma segunda-feira, sempre incluindo o dia selecionado.
  List<DateTime> get stripDays {
    final anchor = filter.start.isBefore(today) ? filter.start : today;
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
    if (_status != AgendaStatus.loading) {
      _status = AgendaStatus.loading;
      _notify();
    }
    _listen();
  }

  /// Recarrega os dados mantendo a lista na tela; só mostra o carregando se
  /// ainda não havia dados.
  void refresh() {
    if (_status != AgendaStatus.ready) {
      start();
      return;
    }
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
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
      _update(filter.copyWith(situation: situation));

  void selectPeriod(AgendaPeriod period) {
    if (period == AgendaPeriod.personalizado) return;
    _update(
      AgendaFilter(
        situation: filter.situation,
        period: period,
        start: period == AgendaPeriod.hoje ? today : filter.start,
      ),
    );
  }

  void selectRange(DateTime start, DateTime end) => _update(
    AgendaFilter(
      situation: filter.situation,
      period: AgendaPeriod.personalizado,
      start: start,
      customEnd: end,
    ),
  );

  void selectDay(DateTime day) {
    final period = filter.period == AgendaPeriod.personalizado
        ? AgendaPeriod.seteDias
        : filter.period;
    _update(
      AgendaFilter(situation: filter.situation, period: period, start: day),
    );
  }

  /// Leva um filtro de outro dia para [today]: se o início ficou no passado,
  /// ele vira hoje, mantendo a situação e o período. Um Personalizado que já
  /// terminou volta para o padrão.
  static AgendaFilter _carriedTo(AgendaFilter filter, DateTime today) {
    if (!filter.start.isBefore(today)) return filter;
    if (filter.period == AgendaPeriod.personalizado &&
        filter.end.isBefore(today)) {
      return AgendaFilter(situation: filter.situation, start: today);
    }
    return filter.copyWith(start: today);
  }

  void _update(AgendaFilter filter) {
    _filter = filter;
    _filterDay = today;
    _memory.write(user.id, filter, _filterDay);
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
