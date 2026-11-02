import 'package:agent_orchestration/confirmation.dart';
import 'package:agent_orchestration/data/biometric_confirmation.dart';

final class UnavailableOnceBiometricConfirmation
    implements BiometricConfirmation {
  @override
  String get methodName => 'Touch ID';

  bool _hasRefused = false;

  @override
  Future<bool> confirm({required String reason}) async {
    if (_hasRefused) {
      return true;
    }

    _hasRefused = true;
    throw const BiometricConfirmationUnavailable(
      explanation: noConfirmationMethodProblem,
    );
  }
}
