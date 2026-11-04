import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

import '../../support/random_inputs.dart';
import '../support/random_run_json.dart';

const String _backendRunCommandText =
    '{"kind":"run_command","tool":"Bash","summary":"Run the tests",'
    '"command":"npm test"}';
const String _backendImproveSkillText =
    '{"kind":"improve_skill",'
    '"skill_id":"0b7c6a52-1d4e-4f0a-9b1e-2c3d4e5f6a7b",'
    '"summary":"1 line added, 1 line removed",'
    '"proposed_instructions":"Write in the present tense."}';
const String _backendSkillChangeText =
    '{"skill_name":"changelog-entries",'
    '"changes":[{"removed":"Write in the past tense."},'
    '{"added":"Write in the present tense."},'
    '{"unchanged":"Skip tests."}]}';

void main() {
  test('test_run_command_to_json_property_round_trips_through_from_json', () {
    final Random random = seededRandom(4301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> wireJson = randomRunCommandJson(random);
      final ApprovalAction decoded = ApprovalAction.fromJson(wireJson);
      final String encodedText = jsonEncode(decoded.toJson());

      expect(decoded, isA<RunCommand>());
      expect(jsonDecode(encodedText), equals(wireJson));
    }
  });

  test('test_approval_action_from_json_property_reads_backend_command', () {
    final Object? backendJson = jsonDecode(_backendRunCommandText);
    final ApprovalAction decoded = ApprovalAction.fromJson(backendJson);

    expect(decoded, isA<RunCommand>());
    final RunCommand command = decoded as RunCommand;
    expect(command.tool, 'Bash');
    expect(command.summary, 'Run the tests');
    expect(command.command, 'npm test');
    expect(jsonEncode(command.toJson()), _backendRunCommandText);
  });

  test('test_run_command_from_json_property_reads_a_stored_command', () {
    final Random random = seededRandom(4305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> wireJson = randomRunCommandJson(random);
      wireJson.remove('summary');

      final ApprovalAction decodedAction = ApprovalAction.fromJson(wireJson);
      final RunCommand decoded = decodedAction as RunCommand;
      final Map<String, Object?> encoded = decoded.toJson();

      expect(decoded.summary, unlabelledCommandSummary);
      expect(decoded.command, wireJson['command']);
      expect(encoded['summary'], unlabelledCommandSummary);
      expect(ApprovalAction.fromJson(encoded).toJson(), equals(encoded));
    }
  });

  test('test_approval_action_from_json_property_command_needs_both_texts', () {
    final Random random = seededRandom(4302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> wireJson = randomRunCommandJson(random);
      final String missingField = pickOne(random, <String>['tool', 'command']);
      final Map<String, Object?> brokenJson = <String, Object?>{
        for (final MapEntry<String, Object?> field in wireJson.entries)
          if (field.key != missingField) field.key: field.value,
      };

      expect(() => ApprovalAction.fromJson(brokenJson), throwsFormatException);
    }
  });

  test(
    'test_improve_skill_to_json_property_round_trips_through_from_json',
    () {
      final Random random = seededRandom(4303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Map<String, Object?> wireJson = randomImproveSkillJson(random);
        final ApprovalAction decoded = ApprovalAction.fromJson(wireJson);
        final String encodedText = jsonEncode(decoded.toJson());

        expect(decoded, isA<ImproveSkill>());
        expect(jsonDecode(encodedText), equals(wireJson));
      }
    },
  );

  test(
    'test_approval_action_from_json_property_reads_backend_improvement',
    () {
      final ApprovalAction decoded = ApprovalAction.fromJson(
        jsonDecode(_backendImproveSkillText),
      );

      expect(decoded, isA<ImproveSkill>());
      final ImproveSkill improvement = decoded as ImproveSkill;
      expect(
        improvement.skillId.value,
        '0b7c6a52-1d4e-4f0a-9b1e-2c3d4e5f6a7b',
      );
      expect(improvement.summary, '1 line added, 1 line removed');
      expect(improvement.proposedInstructions, 'Write in the present tense.');
      expect(jsonEncode(improvement.toJson()), _backendImproveSkillText);
    },
  );

  test('test_skill_change_view_from_json_property_reads_backend_diff', () {
    final SkillChangeView view = SkillChangeView.fromJson(
      jsonDecode(_backendSkillChangeText),
    );

    expect(view.skillName, 'changelog-entries');
    expect(
      <DiffLineChange>[for (final DiffLine line in view.changes) line.change],
      <DiffLineChange>[
        DiffLineChange.removed,
        DiffLineChange.added,
        DiffLineChange.unchanged,
      ],
    );
    expect(view.changes.last.text, 'Skip tests.');
    expect(jsonEncode(view.toJson()), _backendSkillChangeText);
  });

  test('test_approval_view_from_json_property_skill_change_may_be_null', () {
    final Random random = seededRandom(4304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> wireJson = randomApprovalViewJson(random);
      wireJson['skill_change'] = null;

      final ApprovalView view = ApprovalView.fromJson(wireJson);

      expect(view.skillChange, isNull);
      expect(jsonDecode(jsonEncode(view.toJson())), equals(wireJson));
    }
  });
}
