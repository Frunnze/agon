import 'package:local_auth/local_auth.dart';

import 'package:agent_orchestration/data/repository/explained_problem.dart';

const String noConfirmationMethodProblem =
    'This device has no fingerprint, face or passcode lock, so it cannot '
    'confirm signing. Set one up in the system settings and try again.';
const String _lockedOutProblem =
    'Confirmation is locked after too many tries. Unlock the device with '
    'its passcode, then try again.';
const String _alreadyAskingProblem =
    'A confirmation is already open. Finish it first.';
const String _promptFailedProblem =
    'The device could not show its confirmation prompt. Try again.';

final class BiometricConfirmationUnavailable implements ExplainedProblem {
  const BiometricConfirmationUnavailable({required this.explanation});

  @override
  final String explanation;

  @override
  String toString() => explanation;
}

String? describeConfirmationProblem(LocalAuthExceptionCode code) {
  return switch (code) {
    LocalAuthExceptionCode.userCanceled ||
    LocalAuthExceptionCode.systemCanceled ||
    LocalAuthExceptionCode.timeout ||
    LocalAuthExceptionCode.userRequestedFallback => null,
    LocalAuthExceptionCode.noCredentialsSet ||
    LocalAuthExceptionCode.noBiometricsEnrolled ||
    LocalAuthExceptionCode.noBiometricHardware => noConfirmationMethodProblem,
    LocalAuthExceptionCode.temporaryLockout ||
    LocalAuthExceptionCode.biometricLockout => _lockedOutProblem,
    LocalAuthExceptionCode.authInProgress => _alreadyAskingProblem,
    LocalAuthExceptionCode.uiUnavailable ||
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
    LocalAuthExceptionCode.deviceError ||
    LocalAuthExceptionCode.unknownError => _promptFailedProblem,
  };
}
