import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/random_account_json.dart';
import '../support/wire_contract_checks.dart';

const String _rendezvousProblemField = 'rendezvous_problem';

const WireFields _startedPairingFields = WireFields(
  requiredFields: <String>['code', 'display_code', 'started_at', 'expires_at'],
  optionalFields: <String>['joining', _rendezvousProblemField],
  defaultedListFields: <String>[],
);

String? _randomOptionalHostileText(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomHostileText(random);
}

StartedPairing _randomStartedPairing(Random random) {
  final PairingRequestScreen screen = PairingRequestScreen.fromJson(
    randomPairingRequestScreenJson(random),
  );
  return StartedPairing(
    screen: screen,
    rendezvousProblem: _randomOptionalHostileText(random),
  );
}

void main() {
  test('test_started_pairing_constructor_property_keeps_the_screen', () {
    final Random random = seededRandom(73710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingRequestScreen screen = PairingRequestScreen.fromJson(
        randomPairingRequestScreenJson(random),
      );

      final StartedPairing started = StartedPairing(
        screen: screen,
        rendezvousProblem: _randomOptionalHostileText(random),
      );

      expect(identical(started.screen, screen), isTrue);
    }
  });

  test('test_started_pairing_constructor_property_keeps_the_problem_text', () {
    final Random random = seededRandom(73711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? problem = _randomOptionalHostileText(random);

      final StartedPairing started = StartedPairing(
        screen: _randomStartedPairing(random).screen,
        rendezvousProblem: problem,
      );

      expect(started.rendezvousProblem, problem);
    }
  });

  test('test_started_pairing_constructor_property_rebuilt_encodes_same', () {
    final Random random = seededRandom(73712);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StartedPairing started = _randomStartedPairing(random);

      final StartedPairing rebuilt = StartedPairing(
        screen: started.screen,
        rendezvousProblem: started.rendezvousProblem,
      );

      expect(rebuilt.toJson(), equals(started.toJson()));
    }
  });

  test('test_started_pairing_from_json_property_missing_fields_follow', () {
    final Random random = seededRandom(73713);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomStartedPairingJson(random);

      expectRequiredFieldsAreNeeded(
        json,
        _startedPairingFields,
        StartedPairing.fromJson,
      );
      expectOptionalFieldsMayBeLeftOut(
        random,
        json,
        _startedPairingFields,
        StartedPairing.fromJson,
      );
    }
  });

  test('test_started_pairing_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(73714);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomStartedPairingJson(random),
        StartedPairing.fromJson,
      );
    }
  });

  test('test_started_pairing_from_json_property_reads_the_request_screen', () {
    final Random random = seededRandom(73715);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = withUnknownFields(
        random,
        randomStartedPairingJson(random),
      );

      final StartedPairing started = StartedPairing.fromJson(json);
      final PairingRequestScreen screen = PairingRequestScreen.fromJson(json);

      expect(started.screen.toJson(), equals(screen.toJson()));
      expect(started.rendezvousProblem, json[_rendezvousProblemField]);
    }
  });

  test('test_started_pairing_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(73716);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StartedPairing started = _randomStartedPairing(random);

      final Set<String> fields = started.toJson().keys.toSet();

      expect(fields, equals(_startedPairingFields.everyField));
    }
  });

  test('test_started_pairing_to_json_property_flattens_the_screen_fields', () {
    final Random random = seededRandom(73717);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StartedPairing started = _randomStartedPairing(random);

      final JsonObject encoded = started.toJson();
      final JsonObject screenPart = Map<String, Object?>.of(encoded);
      screenPart.remove(_rendezvousProblemField);

      expect(screenPart, equals(started.screen.toJson()));
      expect(encoded[_rendezvousProblemField], started.rendezvousProblem);
    }
  });

  test('test_started_pairing_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(73718);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomStartedPairing(random),
        StartedPairing.fromJson,
      );
    }
  });
}
