import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/refusals.dart';
import 'support/rule_inputs.dart';
import 'support/simulated_scoped_rules.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';

const String _typePrefix = 'test_fake_rule_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 12;
const int _largestSeededCount = 5;
const RuleId _missingRuleId = RuleId('rule-missing');

enum _Focus {
  listRules('list_rules'),
  findRule('find_rule'),
  createRule('create_rule'),
  updateRule('update_rule'),
  deleteRule('delete_rule');

  const _Focus(this.methodName);

  final String methodName;
}

enum _RuleEdit { createRule, updateRule, deleteRule }

sealed class _Step {
  const _Step();
}

final class _SwitchStep extends _Step {
  const _SwitchStep(this.target);

  final WorkspaceId target;
}

final class _EditStep extends _Step {
  const _EditStep({required this.edit, required this.at, required this.draft});

  final _RuleEdit edit;
  final int at;
  final RuleDraft draft;
}

typedef _Pair = ({
  FakeRuleRepository fake,
  NodeBackedRuleRepository nodeBacked,
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
});

bool _isRuleRefusal(Object error) {
  return error is ArgumentError ||
      error is StateError ||
      error is RecordNotFound;
}

Future<_Pair> _buildPair(Random random) async {
  final SeededWorkspaces seeded = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(seeded.workspaces);
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final List<Rule> modelRules = seedSimulatedRules(
    random: random,
    simulated: simulated,
    workspaceIds: workspaceIds,
    count: random.nextInt(_largestSeededCount + 1),
  );
  final NodeBackedRuleRepository nodeBacked = NodeBackedRuleRepository(
    channel: simulated.channel,
    workspaceRepository: seeded.repository,
  );
  await nodeBacked.load();
  final FakeRuleRepository fake = FakeRuleRepository(
    rules: modelRules,
    clock: FixedClock(randomUtcMoment(random)),
    workspaceRepository: seeded.repository,
  );
  return (
    fake: fake,
    nodeBacked: nodeBacked,
    workspaces: seeded.repository,
    workspaceIds: workspaceIds,
  );
}

_RuleEdit _pickFocusedEdit(Random random, _Focus focus) {
  return switch (focus) {
    _Focus.createRule => _RuleEdit.createRule,
    _Focus.updateRule => _RuleEdit.updateRule,
    _Focus.deleteRule => _RuleEdit.deleteRule,
    _Focus.listRules || _Focus.findRule => pickOne(random, _RuleEdit.values),
  };
}

_Step _planStep(Random random, _Pair pair, _Focus focus) {
  final int roll = random.nextInt(4);
  final bool isSwitch = roll == 0 || (focus == _Focus.listRules && roll > 1);
  if (isSwitch) {
    return _SwitchStep(pickOne(random, pair.workspaceIds));
  }

  final _RuleEdit edit = roll == 1
      ? _RuleEdit.createRule
      : _pickFocusedEdit(random, focus);
  final RuleDraft draft = RuleDraft(
    title: pickOne(random, <String>[
      randomWordPhrase(random),
      'Keep ${randomWordPhrase(random)}',
    ]),
    details: randomText(random),
    scope: randomScopeOver(random, pair.workspaceIds),
  );
  final int listedCount = pair.nodeBacked.listRules().length;
  return _EditStep(
    edit: edit,
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

Future<Object?> _applyEdit(RuleRepository repository, _EditStep step) {
  final RuleId ruleId = _pickRuleId(repository, step.at);
  return switch (step.edit) {
    _RuleEdit.createRule => repository.createRule(step.draft),
    _RuleEdit.updateRule => repository.updateRule(ruleId, step.draft),
    _RuleEdit.deleteRule => repository.deleteRule(ruleId),
  };
}

Future<void> _applyStep(_Pair pair, _Step step) async {
  switch (step) {
    case _SwitchStep():
      await pair.workspaces.switchWorkspace(step.target);
    case _EditStep():
      final bool isFakeRefused = await isRefused(
        () => _applyEdit(pair.fake, step),
        isRefusal: _isRuleRefusal,
      );
      final bool isNodeRefused = await isRefused(
        () => _applyEdit(pair.nodeBacked, step),
        isRefusal: _isRuleRefusal,
      );
      expect(isFakeRefused, isNodeRefused, reason: '${step.edit}');
  }
}

void _expectSameFoundRules(_Pair pair) {
  final List<Rule> fakeListing = pair.fake.listRules();
  final List<Rule> nodeListing = pair.nodeBacked.listRules();
  for (int index = 0; index < nodeListing.length; index += 1) {
    final Rule foundInFake = pair.fake.findRule(fakeListing[index].id);
    final Rule foundInNode = pair.nodeBacked.findRule(nodeListing[index].id);
    expect(describeRuleContent(foundInFake), describeRuleContent(foundInNode));
  }
}

Future<void> _expectAgreementUnderFocus({
  required _Focus focus,
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    expect(
      describeRuleListing(pair.fake),
      orderedEquals(describeRuleListing(pair.nodeBacked)),
    );
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      await _applyStep(pair, _planStep(random, pair, focus));

      await pair.nodeBacked.load();
      expect(
        describeRuleListing(pair.fake),
        orderedEquals(describeRuleListing(pair.nodeBacked)),
      );
      _expectSameFoundRules(pair);
    }
    pair.nodeBacked.dispose();
    pair.fake.dispose();
  }
}

void main() {
  for (final _Focus focus in _Focus.values) {
    test('${_typePrefix}_${focus.methodName}_property_agrees_with_the_node_'
        'across_workspaces', () async {
      await _expectAgreementUnderFocus(
        focus: focus,
        seed: 76101 + focus.index,
      );
    });
  }
}
