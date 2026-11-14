import 'package:drift/native.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/app/database/daos/outbox_dao.dart';
import 'package:kym/app/database/daos/stores_dao.dart';
import 'package:kym/app/database/seed/fake_data_seeder.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/equipment/domain/repositories/equipment_repository.dart';
import 'package:kym/modules/orders/domain/repositories/order_repository.dart';
import 'package:kym/modules/stores/domain/repositories/store_repository.dart';

void main() {
  testWidgets('o AppModule injeta banco, DAOs e repositórios', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await FakeDataSeeder(db).seedIfEmpty();

    await tester.pumpWidget(
      ModularApp(
        module: AppModule(
          authDataSourceFactory: () =>
              FakeAuthDataSource(latency: Duration.zero),
          databaseFactory: () => db,
        ),
        child: const KymApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(inject<AppDatabase>(), same(db));
    expect(inject<StoresDao>(), same(db.storesDao));
    expect(inject<OutboxDao>(), same(db.outboxDao));
    expect(inject<StoreRepository>(), isA<StoreRepository>());
    expect(inject<EquipmentRepository>(), isA<EquipmentRepository>());
    expect(inject<OrderRepository>(), isA<OrderRepository>());

    final stores = await tester.runAsync(
      () => inject<StoreRepository>().watchAll().first,
    );
    expect(stores, hasLength(3));
  });
}
