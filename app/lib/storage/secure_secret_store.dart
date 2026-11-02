import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:agent_orchestration/data/secret_store.dart';

final class SecureSecretStore implements SecretStore {
  const SecureSecretStore({required FlutterSecureStorage storage})
    : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readSecret(String name) => _storage.read(key: name);

  @override
  Future<void> writeSecret({required String name, required String value}) {
    return _storage.write(key: name, value: value);
  }
}
