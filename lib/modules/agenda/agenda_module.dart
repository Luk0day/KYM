import 'package:flutter_modular/flutter_modular.dart';

import 'domain/usecases/build_agenda.dart';
import 'domain/usecases/watch_agenda.dart';
import 'presenter/controllers/agenda_controller.dart';

class AgendaModule extends Module {
  @override
  void register(ModularContext c) {
    c
      ..addLazySingleton<WatchAgenda>(WatchAgenda.new)
      ..addLazySingleton<BuildAgenda>(BuildAgenda.new)
      ..addLazySingleton<AgendaFilterMemory>(AgendaFilterMemory.new);
  }
}
