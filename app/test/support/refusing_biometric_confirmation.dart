import 'package:agent_orchestration/data/biometric_confirmation.dart';

final class RefusingBiometricConfirmation implements BiometricConfirmation {
  const RefusingBiometricConfirmation();

  @override
  String get methodName => 'Touch ID';

  @override
  Future<bool> confirm({required String reason}) async => false;
}
