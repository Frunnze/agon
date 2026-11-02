import 'package:agent_orchestration/data/secret_store.dart';

final class MemorySecretStore implements SecretStore {
  final Map<String, String> secrets = <String, String>{};
  int writeCount = 0;

  @override
  Future<String?> readSecret(String name) async => secrets[name];

  @override
  Future<void> writeSecret({
    required String name,
    required String value,
  }) async {
    writeCount += 1;
    secrets[name] = value;
  }
}
