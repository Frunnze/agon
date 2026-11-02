abstract interface class BiometricConfirmation {
  String get methodName;

  Future<bool> confirm({required String reason});
}
