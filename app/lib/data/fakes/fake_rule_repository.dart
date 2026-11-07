import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/current_workspace_records.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/rule_titles.dart';
import 'package:agent_orchestration/data/rules/scope_cleanup.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _ruleKind = 'rule';
const String _createdRulePrefix = 'created-rule-';

String _identifyRule(Rule rule) => rule.id.value;

WorkspaceScope _readWorkspaceScope(Rule rule) => rule.scope.workspaces;

final class FakeRuleRepository extends ChangeNotifier
    implements RuleRepository {
  FakeRuleRepository({
    required List<Rule> rules,
    required Clock clock,
    required WorkspaceRepository workspaceRepository,
  }) : _rules = List<Rule>.unmodifiable(rules),
       _clock = clock,
       _workspaceRepository = workspaceRepository {
    refuseDuplicateIdentifiers(
      rules,
      identify: _identifyRule,
      kind: _ruleKind,
    );
    _workspaceRepository.addListener(notifyListeners);
  }

  final Clock _clock;
  final WorkspaceRepository _workspaceRepository;
  List<Rule> _rules;
  int _createdRuleCount = 0;

  @override
  List<Rule> listRules() {
    return listRecordsInCurrentWorkspace(
      records: _rules,
      workspaceRepository: _workspaceRepository,
      readWorkspaceScope: _readWorkspaceScope,
    );
  }

  @override
  Rule findRule(RuleId ruleId) {
    return findRecord(
      listRules(),
      matches: (Rule rule) => rule.id == ruleId,
      kind: _ruleKind,
      identifier: ruleId.value,
    );
  }

  @override
  Future<Rule> createRule(RuleDraft draft) async {
    requireRuleTitle(draft.title);

    final Rule rule = Rule(
      id: _createRuleId(),
      title: trimUnicodeWhiteSpace(draft.title),
      details: draft.details,
      scope: draft.scope,
      enabled: true,
      addedAt: _clock.now(),
    );

    _rules = appendRecord(_rules, rule);
    notifyListeners();
    return rule;
  }

  @override
  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft) async {
    requireRuleTitle(draft.title);
    final Rule original = findRule(ruleId);

    return _storeRule(
      Rule(
        id: ruleId,
        title: trimUnicodeWhiteSpace(draft.title),
        details: draft.details,
        scope: draft.scope,
        enabled: original.enabled,
        addedAt: original.addedAt,
      ),
    );
  }

  @override
  Future<Rule> turnRuleOn(RuleId ruleId) async {
    return _storeRule(findRule(ruleId).asEnabled());
  }

  @override
  Future<Rule> turnRuleOff(RuleId ruleId) async {
    return _storeRule(findRule(ruleId).asDisabled());
  }

  @override
  Future<void> deleteRule(RuleId ruleId) async {
    findRule(ruleId);

    _rules = removeRecord(_rules, matches: (Rule rule) => rule.id == ruleId);
    notifyListeners();
  }

  void forgetWorkspace({
    required WorkspaceId deletedWorkspaceId,
    required Set<WorkspaceId> remainingWorkspaceIds,
  }) {
    final List<Rule> keptRules = <Rule>[];
    for (final Rule rule in _rules) {
      final Scope scope = forgetWorkspaceInScope(
        rule.scope,
        deletedWorkspaceId,
      );
      if (!isSeenInNoWorkspace(scope.workspaces, remainingWorkspaceIds)) {
        keptRules.add(_withScope(rule, scope));
      }
    }

    _rules = List<Rule>.unmodifiable(keptRules);
    notifyListeners();
  }

  void forgetProjects(Set<ProjectId> deletedProjectIds) {
    _rules = List<Rule>.unmodifiable(<Rule>[
      for (final Rule rule in _rules)
        _withScope(rule, forgetProjectsInScope(rule.scope, deletedProjectIds)),
    ]);
    notifyListeners();
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(notifyListeners);
    super.dispose();
  }

  RuleId _createRuleId() {
    _createdRuleCount += 1;
    final RuleId candidate = RuleId('$_createdRulePrefix$_createdRuleCount');
    final bool isListed = _rules.any((Rule rule) => rule.id == candidate);
    if (isListed) {
      return _createRuleId();
    }
    return candidate;
  }

  Rule _storeRule(Rule rule) {
    _rules = replaceRecord(
      _rules,
      matches: (Rule candidate) => candidate.id == rule.id,
      replacement: rule,
    );
    notifyListeners();
    return rule;
  }
}

Rule _withScope(Rule rule, Scope scope) {
  return Rule(
    id: rule.id,
    title: rule.title,
    details: rule.details,
    scope: scope,
    enabled: rule.enabled,
    addedAt: rule.addedAt,
  );
}
