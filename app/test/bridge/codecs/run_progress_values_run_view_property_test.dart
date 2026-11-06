import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_run_json.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _runViewFields = WireFields(
  requiredFields: <String>['run', 'progress', 'link'],
  optionalFields: <String>['link_lost_at'],
  defaultedListFields: <String>[],
);

RunView _randomLocalRunView(Random random) {
  return RunView(
    run: Run.fromJson(randomRunJson(random)),
    progress: RunProgress.fromJson(randomRunProgressJson(random)),
    link: pickOne(random, RunnerLink.values),
    linkLostAt: randomOptionalLocalMoment(random),
  );
}

void main() {
  test('test_run_view_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53013);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunViewJson(random);

      expectRequiredFieldsAreNeeded(json, _runViewFields, RunView.fromJson);
      expectOptionalFieldsMayBeLeftOut(
        random,
        json,
        _runViewFields,
        RunView.fromJson,
      );
    }
  });

  test('test_run_view_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53014);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomRunViewJson(random),
        RunView.fromJson,
      );
    }
  });

  test('test_run_view_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(53015);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunViewJson(random);

      final RunView view = RunView.fromJson(withUnknownFields(random, json));

      expect(view.run.toJson(), equals(json['run']));
      expect(view.progress.toJson(), equals(json['progress']));
      expect(view.link.wireName, json['link']);
      expectSameMoment(view.linkLostAt, json['link_lost_at']);
    }
  });

  test('test_run_view_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53016);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomLocalRunView(random).toJson();

      expect(encoded.keys.toSet(), equals(_runViewFields.everyField));
    }
  });

  test('test_run_view_to_json_property_values_mirror_the_view_in_utc', () {
    final Random random = seededRandom(53017);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunView view = _randomLocalRunView(random);

      final JsonObject encoded = view.toJson();

      expect(encoded['run'], equals(view.run.toJson()));
      expect(encoded['progress'], equals(view.progress.toJson()));
      expect(encoded['link'], view.link.wireName);
      expectOptionalUtcMomentText(encoded['link_lost_at'], view.linkLostAt);
    }
  });

  test('test_run_view_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(53018);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomLocalRunView(random),
        RunView.fromJson,
      );
    }
  });
}
