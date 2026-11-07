import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/rule_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_scoped_rules.dart';

const String _typePrefix = 'test_fake_rule_repository';

typedef _Forgetting = ({
  WorkspaceRules workspaceRules,
  WorkspaceId deletedWorkspaceId,
  Set<WorkspaceId> remainingWorkspaceIds,
});

_Forgetting _planForgetting(Random random) {
  final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
  final WorkspaceId deletedWorkspaceId = pickOne(
    random,
    workspaceRules.workspaceIds,
  );
  return (
    workspaceRules: workspaceRules,
    deletedWorkspaceId: deletedWorkspaceId,
    remainingWorkspaceIds: randomRemainingWorkspaceIds(
      random,
      workspaceIds: workspaceRules.workspaceIds,
      deletedWorkspaceId: deletedWorkspaceId,
    ),
  );
}

void _forget(_Forgetting forgetting) {
  forgetting.workspaceRules.rules.forgetWorkspace(
    deletedWorkspaceId: forgetting.deletedWorkspaceId,
    remainingWorkspaceIds: forgetting.remainingWorkspaceIds,
  );
}

List<Rule> _predictRulesAfterForget(_Forgetting forgetting) {
  final List<Rule> keptRules = <Rule>[];
  for (final Rule rule in forgetting.workspaceRules.seeded) {
    final Scope scope = predictScopeAfterForget(
      rule.scope,
      forgetting.deletedWorkspaceId,
    );
    if (isModelSeenInNoWorkspace(
      scope.workspaces,
      forgetting.remainingWorkspaceIds,
    )) {
      continue;
    }
    keptRules.add(
      Rule(
        id: rule.id,
        title: rule.title,
        details: rule.details,
        scope: scope,
        enabled: rule.enabled,
        addedAt: rule.addedAt,
      ),
    );
  }
  return keptRules;
}

Future<List<List<String>>> _describeEveryListing(
  WorkspaceRules workspaceRules,
) async {
  return <List<String>>[
    for (final WorkspaceId workspaceId in workspaceRules.workspaceIds)
      await describeListingAfterSwitchingTo(workspaceRules, workspaceId),
  ];
}

Future<Map<RuleId, Rule>> _collectStoredRules(
  WorkspaceRules workspaceRules,
) async {
  final Map<RuleId, Rule> storedRules = <RuleId, Rule>{};
  for (final WorkspaceId workspaceId in workspaceRules.workspaceIds) {
    await workspaceRules.workspaces.switchWorkspace(workspaceId);
    for (final Rule rule in workspaceRules.rules.listRules()) {
      storedRules[rule.id] = rule;
    }
  }
  return storedRules;
}

Map<RuleId, Rule> _indexRules(List<Rule> rules) {
  return <RuleId, Rule>{for (final Rule rule in rules) rule.id: rule};
}

void main() {
  test('${_typePrefix}_forget_workspace_property_matches_the_model', () async {
    final Random random = seededRandom(74101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);
      final WorkspaceRules workspaceRules = forgetting.workspaceRules;

      _forget(forgetting);

      final List<Rule> expectedRules = _predictRulesAfterForget(forgetting);
      for (final WorkspaceId workspaceId in workspaceRules.workspaceIds) {
        final List<String> expected = describeStoredRules(
          filterModelRulesFor(expectedRules, workspaceId),
        );
        expect(
          await describeListingAfterSwitchingTo(workspaceRules, workspaceId),
          orderedEquals(expected),
        );
      }
    }
  });

  test('${_typePrefix}_forget_workspace_property_keeps_all_workspaces_'
      'rules', () async {
    final Random random = seededRandom(74102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);

      _forget(forgetting);

      for (final List<String> listing in await _describeEveryListing(
        forgetting.workspaceRules,
      )) {
        for (final Rule rule in forgetting.workspaceRules.seeded) {
          if (rule.scope.workspaces is AllWorkspaces) {
            expect(listing, contains(describeStoredRule(rule)));
          }
        }
      }
    }
  });

  test('${_typePrefix}_forget_workspace_property_is_idempotent', () async {
    final Random random = seededRandom(74103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);

      _forget(forgetting);
      final List<List<String>> afterOnce = await _describeEveryListing(
        forgetting.workspaceRules,
      );
      _forget(forgetting);
      final List<List<String>> afterTwice = await _describeEveryListing(
        forgetting.workspaceRules,
      );

      expect(afterTwice, equals(afterOnce));
    }
  });

  test('${_typePrefix}_forget_workspace_property_notifies_once', () {
    final Random random = seededRandom(74104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);
      final NotificationCounter notifications = NotificationCounter();
      forgetting.workspaceRules.rules.addListener(notifications.record);

      _forget(forgetting);

      expect(notifications.count, 1);
    }
  });

  test('${_typePrefix}_forget_workspace_property_deleted_workspace_sees_'
      'only_all_workspaces_rules', () async {
    final Random random = seededRandom(74105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);
      final WorkspaceRules workspaceRules = forgetting.workspaceRules;

      _forget(forgetting);

      final List<String> expected = <String>[
        for (final Rule rule in workspaceRules.seeded)
          if (rule.scope.workspaces is AllWorkspaces) describeStoredRule(rule),
      ];
      expect(
        await describeListingAfterSwitchingTo(
          workspaceRules,
          forgetting.deletedWorkspaceId,
        ),
        orderedEquals(expected),
      );
    }
  });

  test('${_typePrefix}_with_scope_property_keeps_every_other_rule_'
      'field', () async {
    final Random random = seededRandom(74106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);
      final Map<RuleId, Rule> seeded = _indexRules(
        forgetting.workspaceRules.seeded,
      );

      _forget(forgetting);

      final Map<RuleId, Rule> stored = await _collectStoredRules(
        forgetting.workspaceRules,
      );
      for (final Rule rule in stored.values) {
        final Rule original = seeded[rule.id]!;
        expect(rule.title, original.title);
        expect(rule.details, original.details);
        expect(rule.enabled, original.enabled);
        expect(rule.addedAt, original.addedAt);
      }
    }
  });

  test('${_typePrefix}_with_scope_property_keeps_the_project_'
      'scope', () async {
    final Random random = seededRandom(74107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);
      final Map<RuleId, Rule> seeded = _indexRules(
        forgetting.workspaceRules.seeded,
      );

      _forget(forgetting);

      final Map<RuleId, Rule> stored = await _collectStoredRules(
        forgetting.workspaceRules,
      );
      for (final Rule rule in stored.values) {
        expect(rule.scope.projects, same(seeded[rule.id]!.scope.projects));
      }
    }
  });

  test('${_typePrefix}_with_scope_property_takes_the_forgotten_workspace_'
      'list', () async {
    final Random random = seededRandom(74108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Forgetting forgetting = _planForgetting(random);
      final Map<RuleId, Rule> expected = _indexRules(
        _predictRulesAfterForget(forgetting),
      );

      _forget(forgetting);

      final Map<RuleId, Rule> stored = await _collectStoredRules(
        forgetting.workspaceRules,
      );
      for (final Rule rule in stored.values) {
        expect(
          describeScope(rule.scope),
          describeScope(expected[rule.id]!.scope),
        );
      }
    }
  });
}
