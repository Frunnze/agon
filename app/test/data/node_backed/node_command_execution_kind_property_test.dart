import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/device_without_account.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';

const String _rustNoAccountKind = 'no_account';
const String _noAccountMessage = 'this device has no account yet';

String _randomNodeMessage(Random random) {
  final List<String> messages = <String>[
    _noAccountMessage,
    randomRefusal(random).nodeMessage,
    'project ${randomHostileText(random)} was not found',
    randomHostileText(random),
  ];
  return pickOne(random, messages);
}

String _randomOtherKind(Random random) {
  while (true) {
    final String kind = randomHostileText(random);
    if (kind != noAccountFailureKind) {
      return kind;
    }
  }
}

String _describeTranslation(Object translated) {
  return '${translated.runtimeType}: $translated';
}

void main() {
  test(
    'test_translate_node_failure_property_no_account_kind_decides_the_type',
    () {
      final Random random = seededRandom(47631);
      expect(noAccountFailureKind, _rustNoAccountKind);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = _randomNodeMessage(random);

        final Object translated = translateNodeFailure(
          NodeCommandFailure(message, kind: noAccountFailureKind),
        );

        expect(translated, isA<DeviceWithoutAccount>());
        expect((translated as StateError).message, message);
      }
    },
  );

  test(
    'test_translate_node_failure_property_the_text_alone_is_no_account_kind',
    () {
      final Random random = seededRandom(47632);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = pickOne(random, <String>[
          _noAccountMessage,
          ' $_noAccountMessage',
          '$_noAccountMessage${randomHostileText(random)}',
        ]);

        final Object translated = translateNodeFailure(
          NodeCommandFailure(message),
        );

        expect(translated, isNot(isA<DeviceWithoutAccount>()));
        expect(translated, isA<StateError>());
        expect((translated as StateError).message, message);
      }
    },
  );

  test(
    'test_translate_node_failure_property_other_kinds_translate_like_none',
    () {
      final Random random = seededRandom(47633);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = _randomNodeMessage(random);

        final Object kinded = translateNodeFailure(
          NodeCommandFailure(message, kind: _randomOtherKind(random)),
        );
        final Object plain = translateNodeFailure(NodeCommandFailure(message));

        expect(_describeTranslation(kinded), _describeTranslation(plain));
      }
    },
  );
}
