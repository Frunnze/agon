import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/refusals.dart';
import 'support/rule_inputs.dart';

const String _typePrefix = 'test_fake_rule_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 10;
const int _largestSeededCount = 4;
const RuleId _missingRuleId = RuleId('rule-missing');

enum _Operation {
  createRule('create_rule'),
  updateRule('update_rule'),
  turnRuleOn('turn_rule_on'),
  turnRuleOff('turn_rule_off'),
  deleteRule('delete_rule');

  const _Operation(this.methodName);

  final String methodName;
}

typedef _Pair = ({
  FakeRuleRepository fake,
  NodeBackedRuleRepository nodeBacked,
});

typedef _PlannedStep = ({_Operation operation, int at, RuleDraft draft});

bool _isRuleRefusal(Object error) {
  return error is ArgumentError ||
      error is StateError ||
      error is RecordNotFound;
}

List<String> _describeListing(RuleRepository repository) {
  return <String>[
    for (final Rule rule in repository.listRules()) describeRuleContent(rule),
  ];
}

Future<_Pair> _buildPair(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final int seededCount = random.nextInt(_largestSeededCount + 1);
  for (int i = 0; i < seededCount; i += 1) {
    final Map<String, Object?> rule = simulated.addRule(
      workspaceId: harnessWorkspaceId.value,
      title: 'Seeded rule $i',
    );
    rule['enabled'] = random.nextBool();
  }
  final WorkspaceRepository workspaceRepository =
      buildSingleWorkspaceRepository();
  final NodeBackedRuleRepository nodeBacked = NodeBackedRuleRepository(
    channel: simulated.channel,
    workspaceRepository: workspaceRepository,
  );
  await nodeBacked.load();
  final FakeRuleRepository fake = FakeRuleRepository(
    rules: nodeBacked.listRules(),
    clock: FixedClock(randomUtcMoment(random)),
    workspaceRepository: workspaceRepository,
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

_PlannedStep _planStep(Random random, _Pair pair, _Operation focus) {
  final int listedCount = pair.nodeBacked.listRules().length;
  final _Operation operation = random.nextInt(3) == 0
      ? _Operation.createRule
      : focus;
  final RuleDraft draft = RuleDraft(
    title: pickOne(random, <String>[
      randomWordPhrase(random),
      'Keep ${randomWordPhrase(random)}',
    ]),
    details: randomText(random),
    scope: randomScope(random),
  );
  return (
    operation: operation,
    at: random.nextInt(listedCount + 1),
    draft: draft,
  );
}

RuleId _pickRuleId(RuleRepository repository, int at) {
  final List<Rule> listed = repository.listRules();
  if (at >= listed.length) {
    return _missingRuleId;
  }
  return listed[at].id;
}

Future<Object?> _applyStep(RuleRepository target, _PlannedStep step) {
  final RuleId ruleId = _pickRuleId(target, step.at);
  return switch (step.operation) {
    _Operation.createRule => target.createRule(step.draft),
    _Operation.updateRule => target.updateRule(ruleId, step.draft),
    _Operation.turnRuleOn => target.turnRuleOn(ruleId),
    _Operation.turnRuleOff => target.turnRuleOff(ruleId),
    _Operation.deleteRule => target.deleteRule(ruleId),
  };
}

Future<void> _checkAgreement({
  required _Operation focus,
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      final _PlannedStep planned = _planStep(random, pair, focus);

      final bool isFakeRefused = await isRefused(
        () => _applyStep(pair.fake, planned),
        isRefusal: _isRuleRefusal,
      );
      final bool isNodeRefused = await isRefused(
        () => _applyStep(pair.nodeBacked, planned),
        isRefusal: _isRuleRefusal,
      );

      expect(isFakeRefused, isNodeRefused, reason: '$planned');
      await pair.nodeBacked.load();
      expect(
        _describeListing(pair.fake),
        orderedEquals(_describeListing(pair.nodeBacked)),
      );
    }
    pair.nodeBacked.dispose();
  }
}

void main() {
  for (final _Operation operation in _Operation.values) {
    test('${_typePrefix}_${operation.methodName}_property_agrees_with_the_'
        'node_backed_repository', () async {
      await _checkAgreement(focus: operation, seed: 66301 + operation.index);
    });
  }
}
