import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import 'support/domain_model_properties.dart';

SkillChange _randomSkillChange(Random random) {
  return SkillChange(
    origin: pickOne<SkillChangeOrigin>(random, <SkillChangeOrigin>[
      const PersonEdit(),
      ApprovedAgentRun(randomRunId(random)),
      AutomaticAgentRun(randomRunId(random)),
    ]),
    savedAt: randomPreciseMoment(random),
    replacedInstructions: randomHostileText(random),
  );
}

List<SkillChange> _randomHistory(Random random) {
  final List<SkillChange> history = <SkillChange>[];
  final int count = random.nextInt(5);
  for (int i = 0; i < count; i += 1) {
    history.add(_randomSkillChange(random));
  }
  return history;
}

ModelFieldValues _randomSkillFields(Random random) {
  return <Object?>[
    SkillId(randomUuidText(random)),
    randomHostileText(random),
    randomHostileText(random),
    randomHostileText(random),
    randomScope(random),
    pickOne(random, SkillUsage.values),
    pickOne(random, SkillSource.values),
    pickOne(random, SkillImprovement.values),
    _randomHistory(random),
  ];
}

Skill _buildSkill(ModelFieldValues fieldValues) {
  return Skill(
    id: fieldValues[0]! as SkillId,
    name: fieldValues[1]! as String,
    summary: fieldValues[2]! as String,
    instructions: fieldValues[3]! as String,
    scope: fieldValues[4]! as Scope,
    usage: fieldValues[5]! as SkillUsage,
    source: fieldValues[6]! as SkillSource,
    improvement: fieldValues[7]! as SkillImprovement,
    history: fieldValues[8]! as List<SkillChange>,
  );
}

void main() {
  testEnumLabelProperties<SkillUsage>(
    testNamePrefix: 'test_skill_usage_label_property',
    choices: SkillUsage.values,
    readLabel: (SkillUsage usage) => usage.label,
  );

  testEnumLabelProperties<SkillImprovement>(
    testNamePrefix: 'test_skill_improvement_label_property',
    choices: SkillImprovement.values,
    readLabel: (SkillImprovement improvement) => improvement.label,
  );

  test('test_skill_improvement_explanation_property_is_unique', () {
    final Set<String> explanations = <String>{};

    for (final SkillImprovement improvement in SkillImprovement.values) {
      explanations.add(improvement.explanation);
    }

    expect(explanations, hasLength(SkillImprovement.values.length));
  });

  test('test_skill_improvement_explanation_property_is_a_sentence', () {
    for (final SkillImprovement improvement in SkillImprovement.values) {
      final String explanation = improvement.explanation;
      final String firstLetter = explanation.substring(0, 1);

      expect(explanation, explanation.trim());
      expect(firstLetter, firstLetter.toUpperCase());
      expect(explanation, endsWith('.'));
      expect(explanation, isNot(contains('\n')));
    }
  });

  test('test_skill_improvement_explanation_property_says_more_than_label', () {
    for (final SkillImprovement improvement in SkillImprovement.values) {
      expect(improvement.explanation, isNot(improvement.label));
      expect(
        improvement.explanation.length,
        greaterThan(improvement.label.length),
      );
    }
  });

  const NodeEnumMapping<SkillUsage, node.SkillUsage> usageMapping =
      NodeEnumMapping<SkillUsage, node.SkillUsage>(
        testNamePrefix: 'test_skill_usage_values_property',
        choices: SkillUsage.values,
        nodeChoices: node.SkillUsage.values,
        mapFromNode: mapSkillUsageFromNode,
      );
  testNodeEnumMappingProperties(usageMapping);
  testNodeEnumRoundTripProperty(usageMapping, mapSkillUsageToNode);

  testNodeEnumMappingProperties(
    const NodeEnumMapping<SkillSource, node.SkillSource>(
      testNamePrefix: 'test_skill_source_values_property',
      choices: SkillSource.values,
      nodeChoices: node.SkillSource.values,
      mapFromNode: mapSkillSourceFromNode,
    ),
  );

  const NodeEnumMapping<SkillImprovement, node.SkillImprovement>
  improvementMapping =
      NodeEnumMapping<SkillImprovement, node.SkillImprovement>(
        testNamePrefix: 'test_skill_improvement_values_property',
        choices: SkillImprovement.values,
        nodeChoices: node.SkillImprovement.values,
        mapFromNode: mapSkillImprovementFromNode,
      );
  testNodeEnumMappingProperties(improvementMapping);
  testNodeEnumRoundTripProperty(improvementMapping, mapSkillImprovementToNode);

  testModelConstructorProperties(
    ModelConstructor<Skill>(
      testNamePrefix: 'test_skill_constructor_property',
      seed: 691101,
      randomFieldValues: _randomSkillFields,
      construct: _buildSkill,
      readFieldValues: (Skill skill) => <Object?>[
        skill.id,
        skill.name,
        skill.summary,
        skill.instructions,
        skill.scope,
        skill.usage,
        skill.source,
        skill.improvement,
        skill.history,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<Skill, SkillChange>(
      testNamePrefix: 'test_skill_constructor_property_history',
      seed: 691111,
      buildElement: _randomSkillChange,
      construct: (Random random, List<SkillChange> history) => Skill(
        id: SkillId(randomUuidText(random)),
        name: randomHostileText(random),
        summary: randomHostileText(random),
        instructions: randomHostileText(random),
        scope: randomScope(random),
        usage: pickOne(random, SkillUsage.values),
        source: pickOne(random, SkillSource.values),
        improvement: pickOne(random, SkillImprovement.values),
        history: history,
      ),
      readList: (Skill skill) => skill.history,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<SkillDraft>(
      testNamePrefix: 'test_skill_draft_constructor_property',
      seed: 691121,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
        randomHostileText(random),
        randomScope(random),
        pickOne(random, SkillUsage.values),
        pickOne(random, SkillImprovement.values),
      ],
      construct: (ModelFieldValues fieldValues) => SkillDraft(
        name: fieldValues[0]! as String,
        summary: fieldValues[1]! as String,
        instructions: fieldValues[2]! as String,
        scope: fieldValues[3]! as Scope,
        usage: fieldValues[4]! as SkillUsage,
        improvement: fieldValues[5]! as SkillImprovement,
      ),
      readFieldValues: (SkillDraft draft) => <Object?>[
        draft.name,
        draft.summary,
        draft.instructions,
        draft.scope,
        draft.usage,
        draft.improvement,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RuleDraft>(
      testNamePrefix: 'test_rule_draft_constructor_property',
      seed: 691131,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
        randomScope(random),
      ],
      construct: (ModelFieldValues fieldValues) => RuleDraft(
        title: fieldValues[0]! as String,
        details: fieldValues[1]! as String,
        scope: fieldValues[2]! as Scope,
      ),
      readFieldValues: (RuleDraft draft) => <Object?>[
        draft.title,
        draft.details,
        draft.scope,
      ],
    ),
  );
}
