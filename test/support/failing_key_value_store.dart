import 'package:kym/app/storage/key_value_store.dart';

class FailingKeyValueStore implements KeyValueStore {
  FailingKeyValueStore({
    this.failReads = false,
    this.failWrites = false,
    this.failDeletes = false,
  });

  final bool failReads;
  final bool failWrites;
  final bool failDeletes;
  final InMemoryKeyValueStore _delegate = InMemoryKeyValueStore();

  @override
  Future<String?> read(String key) async {
    if (failReads) {
      throw Exception('read failed');
    }
    return _delegate.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw Exception('write failed');
    }
    await _delegate.write(key, value);
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) {
      throw Exception('delete failed');
    }
    await _delegate.delete(key);
  }
}
