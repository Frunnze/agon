import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:agent_orchestration/confirmation.dart';

import '../support/random_inputs.dart';

const Set<LocalAuthExceptionCode> _cancellations = <LocalAuthExceptionCode>{
  LocalAuthExceptionCode.userCanceled,
  LocalAuthExceptionCode.systemCanceled,
  LocalAuthExceptionCode.timeout,
  LocalAuthExceptionCode.userRequestedFallback,
};

final class _ScriptedAuthentication extends LocalAuthentication {
  _ScriptedAuthentication({
    required this.isSupported,
    required this.answer,
    required this.failure,
  });

  final bool? isSupported;
  final bool answer;
  final LocalAuthExceptionCode? failure;
  final List<String> askedReasons = <String>[];

  @override
  Future<bool> isDeviceSupported() async {
    final bool? supported = isSupported;
    if (supported == null) {
      throw MissingPluginException('no local authentication here');
    }
    return supported;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const <Object?>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    askedReasons.add(localizedReason);
    final LocalAuthExceptionCode? code = failure;
    if (code != null) {
      throw LocalAuthException(code: code);
    }
    return answer;
  }
}

void main() {
  test('test_confirm_property_returns_the_owner_answer', () async {
    final Random random = seededRandom(9981);
    for (int i = 0; i < propertyIterations; i += 1) {
      final bool answer = random.nextBool();
      final String reason = randomText(random);
      final _ScriptedAuthentication authentication = _ScriptedAuthentication(
        isSupported: true,
        answer: answer,
        failure: null,
      );
      final SystemBiometricConfirmation confirmation =
          SystemBiometricConfirmation(
            authentication: authentication,
            methodName: 'fingerprint',
          );

      expect(await confirmation.confirm(reason: reason), answer);
      expect(authentication.askedReasons, <String>[reason]);
    }
  });

  test('test_confirm_property_unavailable_device_is_refused', () async {
    final Random random = seededRandom(9982);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScriptedAuthentication authentication = _ScriptedAuthentication(
        isSupported: random.nextBool() ? false : null,
        answer: true,
        failure: null,
      );
      final SystemBiometricConfirmation confirmation =
          SystemBiometricConfirmation(
            authentication: authentication,
            methodName: 'fingerprint',
          );

      await expectLater(
        confirmation.confirm(reason: randomText(random)),
        throwsA(
          isA<BiometricConfirmationUnavailable>().having(
            (BiometricConfirmationUnavailable problem) => problem.explanation,
            'explanation',
            isNotEmpty,
          ),
        ),
      );
      expect(authentication.askedReasons, isEmpty);
    }
  });

  test('test_confirm_property_cancellation_is_a_refusal', () async {
    final Random random = seededRandom(9983);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LocalAuthExceptionCode code = pickOne(
        random,
        LocalAuthExceptionCode.values,
      );
      final SystemBiometricConfirmation confirmation =
          SystemBiometricConfirmation(
            authentication: _ScriptedAuthentication(
              isSupported: true,
              answer: true,
              failure: code,
            ),
            methodName: 'fingerprint',
          );

      if (_cancellations.contains(code)) {
        expect(await confirmation.confirm(reason: 'sign'), isFalse);
      } else {
        await expectLater(
          confirmation.confirm(reason: 'sign'),
          throwsA(isA<BiometricConfirmationUnavailable>()),
        );
      }
    }
  });

  test('test_describe_confirmation_problem_property_only_cancels_quietly', () {
    for (final LocalAuthExceptionCode code in LocalAuthExceptionCode.values) {
      final String? problem = describeConfirmationProblem(code);
      expect(problem == null, _cancellations.contains(code));
      if (problem != null) {
        expect(problem, endsWith('.'));
      }
    }
  });
}
