import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import 'logged_computer.dart';

typedef PresenceCall = Future<void> Function();
typedef PresenceReader = bool Function();
typedef SwitchSubjectMaker = SwitchSubject Function(Random random);
typedef FailingCallMaker = PresenceCall Function(Random random);

const int contractIterations = 30;
const String _nativeFailureCode = 'refused';
const int _largestHistoryLength = 6;
const int _largestRepeatCount = 4;

final class SwitchSubject {
  const SwitchSubject({
    required this.implementationName,
    required this.switchOn,
    required this.switchOff,
    required this.readIsOn,
  });

  final String implementationName;
  final PresenceCall switchOn;
  final PresenceCall switchOff;
  final PresenceReader readIsOn;
}

final class NativeSwitchSide {
  NativeSwitchSide({required this.onMethod, required this.offMethod});

  final String onMethod;
  final String offMethod;
  bool isOn = false;

  Future<Object?> answer(MethodCall call) async {
    if (call.method == onMethod) {
      isOn = true;
    }
    if (call.method == offMethod) {
      isOn = false;
    }
    return null;
  }
}

NativeSwitchSide listenAsNativeSwitchSide({
  required MethodChannel channel,
  required String onMethod,
  required String offMethod,
}) {
  final NativeSwitchSide nativeSide = NativeSwitchSide(
    onMethod: onMethod,
    offMethod: offMethod,
  );
  _answerChannel(channel: channel, answer: nativeSide.answer);
  return nativeSide;
}

void listenAsRefusingNativeSide({
  required MethodChannel channel,
  required String failureMessage,
}) {
  _answerChannel(
    channel: channel,
    answer: (MethodCall call) => _refuse(failureMessage),
  );
}

Future<Object?> _refuse(String failureMessage) async {
  throw PlatformException(code: _nativeFailureCode, message: failureMessage);
}

void _answerChannel({
  required MethodChannel channel,
  required Future<Object?> Function(MethodCall call) answer,
}) {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, answer);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

LoggedComputer buildLoggedComputerFailingAt({
  required Random random,
  required String failingEvent,
}) {
  final LoggedComputer computer = LoggedComputer(
    isStartAtLoginChosen: random.nextBool(),
  );
  computer.failingEvent = failingEvent;
  return computer;
}

Future<bool> _applyRandomHistory(Random random, SwitchSubject subject) async {
  bool isExpectedOn = false;
  final int historyLength = random.nextInt(_largestHistoryLength);
  for (int i = 0; i < historyLength; i += 1) {
    isExpectedOn = random.nextBool();
    if (isExpectedOn) {
      await subject.switchOn();
    } else {
      await subject.switchOff();
    }
  }
  return isExpectedOn;
}

Future<void> _expectEveryFailureIsStateError({
  required Random random,
  required List<FailingCallMaker> failingCallMakers,
}) async {
  for (int i = 0; i < contractIterations; i += 1) {
    for (final FailingCallMaker makeFailingCall in failingCallMakers) {
      final PresenceCall failingCall = makeFailingCall(random);
      await expectLater(failingCall(), throwsStateError);
      await expectLater(failingCall(), throwsStateError);
    }
  }
}

void testSwitchOnContract({
  required String testPrefix,
  required int seed,
  required List<SwitchSubjectMaker> subjectMakers,
  required List<FailingCallMaker> failingCallMakers,
}) {
  test('${testPrefix}_sequences_match_the_model', () async {
    final Random random = seededRandom(seed);

    for (int i = 0; i < contractIterations; i += 1) {
      for (final SwitchSubjectMaker makeSubject in subjectMakers) {
        final SwitchSubject subject = makeSubject(random);
        final bool isExpectedOn = await _applyRandomHistory(random, subject);
        expect(subject.readIsOn(), isExpectedOn);

        await subject.switchOn();
        expect(subject.readIsOn(), isTrue, reason: subject.implementationName);
      }
    }
  });

  test('${testPrefix}_repeated_calls_are_safe', () async {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < contractIterations; i += 1) {
      for (final SwitchSubjectMaker makeSubject in subjectMakers) {
        final SwitchSubject subject = makeSubject(random);
        final int repeatCount = 1 + random.nextInt(_largestRepeatCount);
        for (int repeat = 0; repeat < repeatCount; repeat += 1) {
          await subject.switchOn();
          expect(subject.readIsOn(), isTrue);
        }

        await subject.switchOff();
        expect(
          subject.readIsOn(),
          isFalse,
          reason: subject.implementationName,
        );
      }
    }
  });

  test('${testPrefix}_failures_are_state_errors', () async {
    await _expectEveryFailureIsStateError(
      random: seededRandom(seed + 2),
      failingCallMakers: failingCallMakers,
    );
  });
}

void testSwitchOffContract({
  required String testPrefix,
  required int seed,
  required List<SwitchSubjectMaker> subjectMakers,
  required List<FailingCallMaker> failingCallMakers,
}) {
  test('${testPrefix}_after_switching_on_leaves_it_off', () async {
    final Random random = seededRandom(seed);

    for (int i = 0; i < contractIterations; i += 1) {
      for (final SwitchSubjectMaker makeSubject in subjectMakers) {
        final SwitchSubject subject = makeSubject(random);
        await _applyRandomHistory(random, subject);
        await subject.switchOn();

        await subject.switchOff();
        expect(
          subject.readIsOn(),
          isFalse,
          reason: subject.implementationName,
        );
      }
    }
  });

  test('${testPrefix}_never_switched_on_is_safe', () async {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < contractIterations; i += 1) {
      for (final SwitchSubjectMaker makeSubject in subjectMakers) {
        final SwitchSubject subject = makeSubject(random);
        final int repeatCount = 1 + random.nextInt(_largestRepeatCount);
        for (int repeat = 0; repeat < repeatCount; repeat += 1) {
          await subject.switchOff();
          expect(subject.readIsOn(), isFalse);
        }

        await subject.switchOn();
        expect(subject.readIsOn(), isTrue, reason: subject.implementationName);
      }
    }
  });

  test('${testPrefix}_failures_are_state_errors', () async {
    await _expectEveryFailureIsStateError(
      random: seededRandom(seed + 2),
      failingCallMakers: failingCallMakers,
    );
  });
}
