abstract interface class SecretStore {
  Future<String?> readSecret(String name);

  Future<void> writeSecret({required String name, required String value});
}
