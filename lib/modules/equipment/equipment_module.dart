import 'package:flutter_modular/flutter_modular.dart';

import 'domain/usecases/watch_store_equipment.dart';

/// Dependências dos equipamentos (as rotas ficam na casca, no `HomeModule`).
/// Exige `EquipmentRepository` e `OrderRepository` no `AppModule`.
class EquipmentModule extends Module {
  @override
  void register(ModularContext c) {
    c.addLazySingleton<WatchStoreEquipment>(WatchStoreEquipment.new);
  }
}
