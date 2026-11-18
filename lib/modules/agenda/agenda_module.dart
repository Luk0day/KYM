import 'package:flutter_modular/flutter_modular.dart';

import 'domain/usecases/build_agenda.dart';
import 'domain/usecases/watch_agenda.dart';
import 'presenter/controllers/agenda_controller.dart';
import 'presenter/utils/agenda_clock.dart';

class AgendaModule extends Module {
  AgendaModule({this.clock = const AgendaClock()});

  final AgendaClock clock;

  @override
  void register(ModularContext c) {
    c
      ..addInstance<AgendaClock>(clock)
      ..addLazySingleton<WatchAgenda>(WatchAgenda.new)
      ..addLazySingleton<BuildAgenda>(BuildAgenda.new)
      ..addLazySingleton<AgendaFilterMemory>(AgendaFilterMemory.new);
  }
}
