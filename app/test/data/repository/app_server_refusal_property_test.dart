import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';

AppServerRefusal _buildRefusal(RandomRefusal refusal) {
  return AppServerRefusal(status: refusal.status, reason: refusal.reason);
}

void main() {
  test('test_app_server_refusal_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(77301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomRefusal refusal = randomRefusal(random);

      final AppServerRefusal built = _buildRefusal(refusal);

      expect(built.status, refusal.status);
      expect(built.message, refusal.reason);
    }
  });

  test('test_app_server_refusal_constructor_property_is_a_state_error', () {
    final Random random = seededRandom(77302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerRefusal built = _buildRefusal(randomRefusal(random));

      expect(built, isA<StateError>());
      expect(built, isA<Error>());
    }
  });

  test(
    'test_app_server_refusal_constructor_property_people_see_the_reason',
    () {
      final Random random = seededRandom(77303);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RandomRefusal refusal = randomRefusal(random);

        final String? shown = describeProblemForPeople(_buildRefusal(refusal));

        expect(shown, refusal.reason);
      }
    },
  );

  test('test_app_server_refusal_to_string_property_renders_the_node_text', () {
    final Random random = seededRandom(77304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomRefusal refusal = randomRefusal(random);

      expect(_buildRefusal(refusal).toString(), refusal.nodeMessage);
    }
  });

  test('test_app_server_refusal_to_string_property_translates_back', () {
    final Random random = seededRandom(77305);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerRefusal built = _buildRefusal(randomRefusal(random));

      final Object translated = translateNodeFailure(
        NodeCommandFailure(built.toString()),
      );

      expect((translated as AppServerRefusal).status, built.status);
      expect(translated.message, built.message);
    }
  });

  test('test_app_server_refusal_to_string_property_ends_with_the_reason', () {
    final Random random = seededRandom(77306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerRefusal built = _buildRefusal(randomRefusal(random));
      final String rendered = built.toString();

      expect(rendered, startsWith(appServerRefusalPrefix));
      expect(rendered, endsWith(built.message));
      expect(rendered, contains('${built.status}'));
    }
  });
}
