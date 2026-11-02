import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/channel_presence.dart';
import 'package:agent_orchestration/background/login_item.dart';

import '../support/random_inputs.dart';

const MethodChannel _channel = MethodChannel('test/runner_presence');
const String _platformErrorCode = 'presence';

final class _NativeSide {
  final List<String> methods = <String>[];
  String? failureMessage;

  Future<Object?> answer(MethodCall call) async {
    methods.add(call.method);
    final String? message = failureMessage;
    if (message != null) {
      throw PlatformException(code: _platformErrorCode, message: message);
    }
    return null;
  }
}

_NativeSide _listenAsNativeSide() {
  final _NativeSide nativeSide = _NativeSide();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, nativeSide.answer);
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  return nativeSide;
}

Matcher _throwsProblem({required String problem, required String detail}) {
  return throwsA(
    isA<StateError>().having(
      (StateError error) => error.message,
      'message',
      '$problem: $detail',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('test_register_property_asks_the_native_side_by_name', () async {
    final Random random = seededRandom(12401);
    final _NativeSide nativeSide = _listenAsNativeSide();
    const ChannelLoginItem loginItem = ChannelLoginItem(channel: _channel);
    final List<String> expectedMethods = <String>[];

    for (int i = 0; i < propertyIterations; i += 1) {
      if (random.nextBool()) {
        await loginItem.register();
        expectedMethods.add(registerLoginItemMethod);
      } else {
        await loginItem.unregister();
        expectedMethods.add(unregisterLoginItemMethod);
      }
    }

    expect(nativeSide.methods, expectedMethods);
  });

  test('test_stay_in_tray_property_asks_the_native_side_by_name', () async {
    final Random random = seededRandom(12402);
    final _NativeSide nativeSide = _listenAsNativeSide();
    const ChannelTrayPresence trayPresence = ChannelTrayPresence(
      channel: _channel,
    );
    final List<String> expectedMethods = <String>[];

    for (int i = 0; i < propertyIterations; i += 1) {
      if (random.nextBool()) {
        await trayPresence.stayInTray();
        expectedMethods.add(stayInTrayMethod);
      } else {
        await trayPresence.leaveTray();
        expectedMethods.add(leaveTrayMethod);
      }
    }

    expect(nativeSide.methods, expectedMethods);
  });

  test(
    'test_call_presence_method_property_native_failures_explain_themselves',
    () async {
      final Random random = seededRandom(12403);
      final _NativeSide nativeSide = _listenAsNativeSide();
      const ChannelLoginItem loginItem = ChannelLoginItem(channel: _channel);
      const ChannelTrayPresence trayPresence = ChannelTrayPresence(
        channel: _channel,
      );

      for (int i = 0; i < propertyIterations; i += 1) {
        final String detail = randomText(random);
        nativeSide.failureMessage = detail;

        await expectLater(
          loginItem.register(),
          _throwsProblem(problem: startAtLoginProblem, detail: detail),
        );
        await expectLater(
          loginItem.unregister(),
          _throwsProblem(problem: stopStartingAtLoginProblem, detail: detail),
        );
        await expectLater(
          trayPresence.stayInTray(),
          _throwsProblem(problem: stayInTrayProblem, detail: detail),
        );
        await expectLater(
          trayPresence.leaveTray(),
          _throwsProblem(problem: leaveTrayProblem, detail: detail),
        );
      }
    },
  );

  test(
    'test_call_presence_method_property_missing_native_side_is_explained',
    () async {
      const ChannelLoginItem loginItem = ChannelLoginItem(channel: _channel);
      const ChannelTrayPresence trayPresence = ChannelTrayPresence(
        channel: _channel,
      );
      final Matcher throwsStartProblem = throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          startsWith('$startAtLoginProblem: '),
        ),
      );

      await expectLater(loginItem.register(), throwsStartProblem);
      await expectLater(trayPresence.stayInTray(), throwsStateError);
      await expectLater(trayPresence.leaveTray(), throwsStateError);
      await expectLater(loginItem.unregister(), throwsStateError);
    },
  );
}
