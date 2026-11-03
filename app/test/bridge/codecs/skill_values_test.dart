import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_catalog_json.dart';

const String _backendSkillText =
    '{"id":"3f2a1b0c-9d8e-4f7a-8b6c-5d4e3f2a1b0c",'
    '"name":"ios-release",'
    '"summary":"Build, sign and upload the iOS app",'
    '"instructions":"Build it.\\nSign it.",'
    '"scope":{"workspaces":{"kind":"all_workspaces"},'
    '"projects":{"kind":"all_projects"}},'
    '"usage":"automatic",'
    '"source":"created",'
    '"improvement":"ask_me",'
    '"history":['
    '{"origin":{"kind":"person_edit"},'
    '"saved_at":"2026-10-24T09:00:00.000Z",'
    '"replaced_instructions":"Build it."},'
    '{"origin":{"kind":"automatic_agent_run",'
    '"run_id":"7a6b5c4d-3e2f-4a1b-9c8d-7e6f5a4b3c2d"},'
    '"saved_at":"2026-10-26T09:00:00.000Z",'
    '"replaced_instructions":"Build it.\\nUpload it."},'
    '{"origin":{"kind":"approved_agent_run",'
    '"run_id":"1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d"},'
    '"saved_at":"2026-10-29T12:00:00.000Z",'
    '"replaced_instructions":"Build it.\\nShip it."}]}';

void main() {
  test('test_skill_from_json_property_reads_backend_history_in_order', () {
    final Skill skill = Skill.fromJson(jsonDecode(_backendSkillText));

    expect(skill.improvement, SkillImprovement.askMe);
    expect(skill.history.length, 3);
    expect(skill.history.first.origin, isA<PersonEdit>());
    final SkillChangeOrigin automatic = skill.history[1].origin;
    expect(automatic, isA<AutomaticAgentRun>());
    expect(
      (automatic as AutomaticAgentRun).runId.value,
      '7a6b5c4d-3e2f-4a1b-9c8d-7e6f5a4b3c2d',
    );
    final SkillChangeOrigin approved = skill.history.last.origin;
    expect(approved, isA<ApprovedAgentRun>());
    expect(skill.history.last.savedAt, DateTime.utc(2026, 10, 29, 12));
    expect(skill.history.last.replacedInstructions, 'Build it.\nShip it.');
    expect(jsonEncode(skill.toJson()), _backendSkillText);
  });

  test('test_skill_from_json_property_missing_history_reads_as_none', () {
    final Random random = seededRandom(4311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject older = randomSkillJson(random);
      older.remove('history');

      final Skill skill = Skill.fromJson(older);

      expect(skill.history, isEmpty);
      expect(skill.toJson()['history'], isEmpty);
    }
  });

  test('test_skill_from_json_property_improvement_is_required', () {
    final Random random = seededRandom(4312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject broken = randomSkillJson(random);
      broken.remove('improvement');

      expect(() => Skill.fromJson(broken), throwsFormatException);
    }
  });

  test(
    'test_skill_change_origin_from_json_property_agent_runs_need_a_run',
    () {
      final Random random = seededRandom(4313);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String kind = pickOne(random, <String>[
          'approved_agent_run',
          'automatic_agent_run',
        ]);

        expect(
          () => SkillChangeOrigin.fromJson(<String, Object?>{'kind': kind}),
          throwsFormatException,
        );
        expect(
          () => SkillChangeOrigin.fromJson(<String, Object?>{
            'kind': '${randomText(random)}?',
          }),
          throwsFormatException,
        );
      }
    },
  );
}
