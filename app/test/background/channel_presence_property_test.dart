import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/channel_presence.dart';
import 'package:agent_orchestration/background/login_item.dart';

import '../support/random_inputs.dart';

typedef _PresenceCall = Future<void> Function();

const MethodChannel _channel = MethodChannel('test/channel_presence');
const ChannelLoginItem _loginItem = ChannelLoginItem(channel: _channel);
const ChannelTrayPresence _trayPresence = ChannelTrayPresence(
  channel: _channel,
);
const List<String> _nativeErrorCodes = <String>[
  'login_item',
  'tray',
  'error',
  'E_42',
];
const List<Object?> _successAnswers = <Object?>[
  null,
  '',
  'done',
  0,
  true,
  <Object?>[],
  <String, Object?>{'state': 'shown'},
];

final class _PresenceOperation {
  const _PresenceOperation({
    required this.method,
    required this.problem,
    required this.call,
  });

  final String method;
  final String problem;
  final _PresenceCall call;
}

final _PresenceOperation _register = _PresenceOperation(
  method: registerLoginItemMethod,
  problem: startAtLoginProblem,
  call: _loginItem.register,
);
final _PresenceOperation _unregister = _PresenceOperation(
  method: unregisterLoginItemMethod,
  problem: stopStartingAtLoginProblem,
  call: _loginItem.unregister,
);
final _PresenceOperation _stayInTray = _PresenceOperation(
  method: stayInTrayMethod,
  problem: stayInTrayProblem,
  call: _trayPresence.stayInTray,
);
final _PresenceOperation _leaveTray = _PresenceOperation(
  method: leaveTrayMethod,
  problem: leaveTrayProblem,
  call: _trayPresence.leaveTray,
);
final List<_PresenceOperation> _operations = <_PresenceOperation>[
  _register,
  _unregister,
  _stayInTray,
  _leaveTray,
];

final class _ScriptedNativeSide {
  Set<String> implementedMethods = <String>{
    registerLoginItemMethod,
    unregisterLoginItemMethod,
    stayInTrayMethod,
    leaveTrayMethod,
  };
  PlatformException? failure;
  Object? successAnswer;
  final List<MethodCall> calls = <MethodCall>[];

  Future<Object?> answer(MethodCall call) async {
    calls.add(call);
    if (!implementedMethods.contains(call.method)) {
      throw MissingPluginException();
    }
    final PlatformException? scriptedFailure = failure;
    if (scriptedFailure != null) {
      throw scriptedFailure;
    }
    return successAnswer;
  }
}

_ScriptedNativeSide _listenAsNativeSide() {
  final _ScriptedNativeSide nativeSide = _ScriptedNativeSide();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, nativeSide.answer);
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  return nativeSide;
}

String? _randomNativeMessage(Random random) {
  final String text = randomText(random);
  if (random.nextInt(3) == 0 || text.trim().isEmpty) {
    return null;
  }
  return text;
}

Matcher _throwsStateErrorWith(Matcher messageMatcher) {
  return throwsA(
    isA<StateError>().having(
      (StateError error) => error.message,
      'message',
      messageMatcher,
    ),
  );
}

Future<void> _expectOneBareCallPerUse(
  _PresenceOperation operation, {
  required int seed,
}) async {
  final Random random = seededRandom(seed);
  final _ScriptedNativeSide nativeSide = _listenAsNativeSide();

  for (int i = 0; i < propertyIterations; i += 1) {
    _PresenceOperation chosen = operation;
    if (random.nextBool()) {
      chosen = pickOne(random, _operations);
    }
    nativeSide.successAnswer = pickOne(random, _successAnswers);
    final int callCountBefore = nativeSide.calls.length;

    await chosen.call();

    expect(nativeSide.calls.length, callCountBefore + 1);
    expect(nativeSide.calls.last.method, chosen.method);
    expect(nativeSide.calls.last.arguments, isNull);
  }
}

Future<void> _expectNativeFailuresExplained(
  _PresenceOperation operation, {
  required int seed,
}) async {
  final Random random = seededRandom(seed);
  final _ScriptedNativeSide nativeSide = _listenAsNativeSide();

  for (int i = 0; i < propertyIterations; i += 1) {
    final String code = pickOne(random, _nativeErrorCodes);
    final String? message = _randomNativeMessage(random);
    nativeSide.failure = PlatformException(code: code, message: message);
    final String reason = message ?? code;

    await expectLater(
      operation.call(),
      _throwsStateErrorWith(equals('${operation.problem}: $reason')),
    );
  }
}

Future<void> _expectMissingMethodsExplained(
  _PresenceOperation operation, {
  required int seed,
}) async {
  final Random random = seededRandom(seed);
  final _ScriptedNativeSide nativeSide = _listenAsNativeSide();

  for (int i = 0; i < propertyIterations; i += 1) {
    final Set<String> implementedMethods = <String>{};
    for (final _PresenceOperation other in _operations) {
      if (random.nextBool()) {
        implementedMethods.add(other.method);
      }
    }
    nativeSide.implementedMethods = implementedMethods;

    if (implementedMethods.contains(operation.method)) {
      await operation.call();
      continue;
    }
    await expectLater(
      operation.call(),
      _throwsStateErrorWith(
        allOf(
          startsWith('${operation.problem}: '),
          contains(operation.method),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'test_call_presence_method_property_a_failure_never_spoils_the_next_call',
    () async {
      final Random random = seededRandom(48101);
      final _ScriptedNativeSide nativeSide = _listenAsNativeSide();
      final List<String> expectedMethods = <String>[];

      for (int i = 0; i < propertyIterations; i += 1) {
        final _PresenceOperation operation = pickOne(random, _operations);
        final bool isFailing = random.nextInt(3) == 0;
        nativeSide.failure = null;
        if (isFailing) {
          nativeSide.failure = PlatformException(
            code: pickOne(random, _nativeErrorCodes),
          );
        }
        expectedMethods.add(operation.method);

        if (isFailing) {
          await expectLater(operation.call(), throwsStateError);
        } else {
          await operation.call();
        }

        final List<String> sentMethods = <String>[];
        for (final MethodCall call in nativeSide.calls) {
          sentMethods.add(call.method);
        }
        expect(sentMethods, expectedMethods);
      }
    },
  );

  test(
    'test_channel_login_item_register_property_sends_one_bare_call_per_use',
    () => _expectOneBareCallPerUse(_register, seed: 48102),
  );

  test(
    'test_channel_login_item_register_property_missing_method_is_explained',
    () => _expectMissingMethodsExplained(_register, seed: 48103),
  );

  test(
    'test_channel_login_item_unregister_property_sends_one_bare_call_per_use',
    () => _expectOneBareCallPerUse(_unregister, seed: 48104),
  );

  test(
    'test_channel_login_item_unregister_property_native_failure_is_explained',
    () => _expectNativeFailuresExplained(_unregister, seed: 48105),
  );

  test(
    'test_channel_login_item_unregister_property_missing_method_is_explained',
    () => _expectMissingMethodsExplained(_unregister, seed: 48106),
  );

  test(
    'test_channel_tray_presence_stay_in_tray_property_one_bare_call_per_use',
    () => _expectOneBareCallPerUse(_stayInTray, seed: 48107),
  );

  test(
    'test_channel_tray_presence_stay_in_tray_property_missing_is_explained',
    () => _expectMissingMethodsExplained(_stayInTray, seed: 48108),
  );

  test(
    'test_channel_tray_presence_leave_tray_property_one_bare_call_per_use',
    () => _expectOneBareCallPerUse(_leaveTray, seed: 48109),
  );

  test(
    'test_channel_tray_presence_leave_tray_property_failure_is_explained',
    () => _expectNativeFailuresExplained(_leaveTray, seed: 48110),
  );

  test(
    'test_channel_tray_presence_leave_tray_property_missing_is_explained',
    () => _expectMissingMethodsExplained(_leaveTray, seed: 48111),
  );
}
