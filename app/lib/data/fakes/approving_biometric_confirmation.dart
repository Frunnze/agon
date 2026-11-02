import 'package:agent_orchestration/data/biometric_confirmation.dart';

final class ApprovingBiometricConfirmation implements BiometricConfirmation {
  const ApprovingBiometricConfirmation({required this.methodName});

  @override
  final String methodName;

  @override
  Future<bool> confirm({required String reason}) async => true;
}
