import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import 'support/task_argument_models.dart';

const int _firstSeed = 7361000;
const String _strayField = 'stray';
const String _doerField = 'doer';

void main() {
  test('test_task_arguments_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledTaskArguments modelled = randomModelledTaskArguments(
        random,
      );

      expect(
        readTaskArgumentFields(modelled.arguments),
        orderedEquals(modelled.givenFields),
      );
      expect(modelled.arguments.skills, orderedEquals(modelled.givenSkills));
    }
  });

  testListCopyProperties(
    const ListCopy<TaskArguments, SkillId>(
      testNamePrefix: 'test_task_arguments_constructor_property_skills',
      seed: _firstSeed + 1,
      buildElement: _randomSkillId,
      construct: _buildArgumentsWithSkills,
      readList: _readSkills,
    ),
  );

  test('test_task_arguments_to_json_property_matches_the_rust_model', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledTaskArguments modelled = randomModelledTaskArguments(
        random,
      );
      final Object? sentJson = rereadThroughWire(modelled.arguments.toJson());

      expect(sentJson, equals(modelled.expectedJson));
    }
  });

  test('test_task_arguments_to_json_property_survives_json_text', () {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject taskJson = randomModelledTaskArguments(random).arguments
          .toJson();

      expect(rereadThroughWire(taskJson), equals(taskJson));
    }
  });

  test('test_task_arguments_to_json_property_is_fresh_on_every_read', () {
    final Random random = seededRandom(_firstSeed + 6);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledTaskArguments modelled = randomModelledTaskArguments(
        random,
      );
      final JsonObject firstRead = modelled.arguments.toJson();
      final JsonObject firstDoer = firstRead[_doerField]! as JsonObject;
      firstDoer[_strayField] = randomText(random);
      firstRead[_strayField] = randomText(random);
      firstRead.remove(pickOne(random, firstRead.keys.toList()));

      expect(
        rereadThroughWire(modelled.arguments.toJson()),
        equals(modelled.expectedJson),
      );
    }
  });

  test('test_task_arguments_to_json_property_different_tasks_differ', () {
    final Random random = seededRandom(_firstSeed + 7);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledTaskArguments first = randomModelledTaskArguments(random);
      final ModelledTaskArguments second = randomModelledTaskArguments(random);
      final bool sameModels =
          jsonEncode(first.expectedJson) == jsonEncode(second.expectedJson);
      final bool sameSentJson =
          jsonEncode(first.arguments.toJson()) ==
          jsonEncode(second.arguments.toJson());

      expect(sameSentJson, sameModels);
    }
  });
}

SkillId _randomSkillId(Random random) => SkillId(randomHostileText(random));

TaskArguments _buildArgumentsWithSkills(Random random, List<SkillId> skills) {
  final TaskArguments template = randomModelledTaskArguments(random).arguments;
  return TaskArguments(
    workspaceId: template.workspaceId,
    projectId: template.projectId,
    title: template.title,
    details: template.details,
    doer: template.doer,
    runsOn: template.runsOn,
    agentPlace: template.agentPlace,
    skills: skills,
    usesAutomaticSkills: template.usesAutomaticSkills,
    approvalPolicy: template.approvalPolicy,
  );
}

List<SkillId> _readSkills(TaskArguments arguments) => arguments.skills;
