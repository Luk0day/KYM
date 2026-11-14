import 'package:supabase_flutter/supabase_flutter.dart';

class InMemoryLocalStorage extends LocalStorage {
  InMemoryLocalStorage([this.session]);

  String? session;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => session != null;

  @override
  Future<String?> accessToken() async => session;

  @override
  Future<void> removePersistedSession() async {
    session = null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    session = persistSessionString;
  }
}
