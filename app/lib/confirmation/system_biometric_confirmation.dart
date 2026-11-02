import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:agent_orchestration/confirmation.dart';
import 'package:agent_orchestration/data/biometric_confirmation.dart';

final class SystemBiometricConfirmation implements BiometricConfirmation {
  const SystemBiometricConfirmation({
    required LocalAuthentication authentication,
    required this.methodName,
  }) : _authentication = authentication;

  final LocalAuthentication _authentication;

  @override
  final String methodName;

  @override
  Future<bool> confirm({required String reason}) async {
    final bool isSupported = await _isConfirmationSupported();
    if (!isSupported) {
      throw const BiometricConfirmationUnavailable(
        explanation: noConfirmationMethodProblem,
      );
    }

    try {
      return await _authentication.authenticate(localizedReason: reason);
    } on LocalAuthException catch (failure) {
      final String? problem = describeConfirmationProblem(failure.code);
      if (problem == null) {
        return false;
      }
      throw BiometricConfirmationUnavailable(explanation: problem);
    }
  }

  Future<bool> _isConfirmationSupported() async {
    try {
      return await _authentication.isDeviceSupported();
    } on MissingPluginException {
      return false;
    }
  }
}
