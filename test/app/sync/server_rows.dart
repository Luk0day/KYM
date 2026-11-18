// Linhas como o Supabase devolve, para os testes da baixada (B20).

const t0 = '2026-11-18T10:00:00.000Z';

String stamp(int seconds) => DateTime.parse(t0)
    .add(Duration(seconds: seconds))
    .toUtc()
    .toIso8601String();

Map<String, Object?> serverStore(String id, {int at = 0, String? name}) => {
      'id': id,
      'name': name ?? 'Loja $id',
      'code': null,
      'address': 'Rua $id',
      'city': 'Recife',
      'latitude': -8.05,
      'longitude': -34.9,
      'qr_token': 'qr-$id',
      'active': true,
      'created_at': t0,
      'updated_at': stamp(at),
    };

Map<String, Object?> serverEquipment(
  String id,
  String storeId, {
  int at = 0,
  String status = 'operando',
}) =>
    {
      'id': id,
      'store_id': storeId,
      'name': 'Freezer $id',
      'category': null,
      'brand': null,
      'model': null,
      'serial_number': 'SN-$id',
      'qr_token': 'qr-$id',
      'status': status,
      'installed_at': '2026-01-15',
      'notes': null,
      'created_at': t0,
      'updated_at': stamp(at),
    };

Map<String, Object?> serverOrder(
  String id,
  String equipmentId,
  String storeId, {
  int at = 0,
  String status = 'aberta',
}) =>
    {
      'id': id,
      'equipment_id': equipmentId,
      'store_id': storeId,
      'type': 'corretiva',
      'status': status,
      'description': 'Não gela',
      'notes': null,
      'scheduled_for': '2026-11-20',
      'opened_by': 'u-lojista',
      'assigned_to': null,
      'started_at': null,
      'completed_at': null,
      'created_at': t0,
      'updated_at': stamp(at),
    };

Map<String, Object?> serverPhoto(String id, String orderId, {int at = 0}) => {
      'id': id,
      'order_id': orderId,
      'storage_path': 'orders/$orderId/$id.jpg',
      'kind': 'chamado',
      'taken_at': t0,
      'created_by': 'u-lojista',
      'updated_at': stamp(at),
    };

