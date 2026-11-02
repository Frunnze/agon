import 'package:agent_orchestration/data/biometric_confirmation.dart';

final class RecordingBiometricConfirmation implements BiometricConfirmation {
  RecordingBiometricConfirmation({required this.answer});

  @override
  String get methodName => 'Touch ID';

  final bool answer;
  final List<String> askedReasons = <String>[];

  @override
  Future<bool> confirm({required String reason}) async {
    askedReasons.add(reason);
    return answer;
  }
}
