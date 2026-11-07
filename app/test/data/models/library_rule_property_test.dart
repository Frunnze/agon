import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_moments.dart';
import '../../support/sample_scopes.dart';
import 'support/domain_model_properties.dart';

ModelFieldValues _randomRuleFields(Random random) {
  return <Object?>[
    RuleId(randomUuidText(random)),
    randomHostileText(random),
    randomHostileText(random),
    randomScope(random),
    random.nextBool(),
    randomPreciseMoment(random),
  ];
}

Rule _buildRule(ModelFieldValues fieldValues) {
  return Rule(
    id: fieldValues[0]! as RuleId,
    title: fieldValues[1]! as String,
    details: fieldValues[2]! as String,
    scope: fieldValues[3]! as Scope,
    enabled: fieldValues[4]! as bool,
    addedAt: fieldValues[5]! as DateTime,
  );
}

Rule _randomRule(Random random) => _buildRule(_randomRuleFields(random));

ModelFieldValues _readFieldsBesidesEnabled(Rule rule) {
  return <Object?>[
    rule.id,
    rule.title,
    rule.details,
    rule.scope,
    rule.addedAt,
  ];
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<Rule>(
      testNamePrefix: 'test_rule_constructor_property',
      seed: 691201,
      randomFieldValues: _randomRuleFields,
      construct: _buildRule,
      readFieldValues: (Rule rule) => <Object?>[
        rule.id,
        rule.title,
        rule.details,
        rule.scope,
        rule.enabled,
        rule.addedAt,
      ],
    ),
  );

  testModelCopyProperties(
    ModelCopy<Rule, bool>(
      testNamePrefix: 'test_as_enabled_property',
      seed: 691211,
      randomModel: _randomRule,
      randomChange: (Random random) => true,
      applyChange: (Rule rule, bool enabled) => rule.asEnabled(),
      readChangedField: (Rule rule) => rule.enabled,
      readOtherFields: _readFieldsBesidesEnabled,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Rule, bool>(
      testNamePrefix: 'test_as_disabled_property',
      seed: 691221,
      randomModel: _randomRule,
      randomChange: (Random random) => false,
      applyChange: (Rule rule, bool enabled) => rule.asDisabled(),
      readChangedField: (Rule rule) => rule.enabled,
      readOtherFields: _readFieldsBesidesEnabled,
    ),
  );
}
