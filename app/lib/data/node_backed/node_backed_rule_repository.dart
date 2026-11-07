import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/library_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/rule_titles.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _ruleKind = 'rule';
const Set<node.ChangeArea> _ruleAreas = <node.ChangeArea>{
  node.ChangeArea.rules,
};

final class NodeBackedRuleRepository extends ChangeNotifier
    implements RuleRepository, NodeSynchronized {
  NodeBackedRuleRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository {
    _workspaceRepository.addListener(_loadAfterWorkspaceChange);
  }

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final FetchSequence _fetches = FetchSequence();
  List<Rule> _rules = const <Rule>[];

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final List<Rule> rules = await _loadRules();
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    _rules = rules;
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    if (isChangeInAreas(topic, _ruleAreas)) {
      await load();
    }
  }

  @override
  List<Rule> listRules() => _rules;

  @override
  Rule findRule(RuleId ruleId) {
    return findRecord(
      _rules,
      matches: (Rule rule) => rule.id == ruleId,
      kind: _ruleKind,
      identifier: ruleId.value,
    );
  }

  @override
  Future<Rule> createRule(RuleDraft draft) async {
    requireRuleTitle(draft.title);

    final node.Rule created = await executeNodeCommand(
      _channel,
      node.CreateRuleCommand(
        workspaceId: _workspaceRepository.currentWorkspace().id,
        title: trimUnicodeWhiteSpace(draft.title),
        details: draft.details,
        scope: mapScopeToNode(draft.scope),
      ),
    );
    return _storeRule(mapRuleFromNode(created));
  }

  @override
  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft) async {
    requireRuleTitle(draft.title);

    final node.Rule updated = await executeNodeCommand(
      _channel,
      node.UpdateRuleCommand(
        workspaceId: _workspaceRepository.currentWorkspace().id,
        ruleId: ruleId,
        title: trimUnicodeWhiteSpace(draft.title),
        details: draft.details,
        scope: mapScopeToNode(draft.scope),
      ),
    );
    return _storeRule(mapRuleFromNode(updated));
  }

  @override
  Future<Rule> turnRuleOn(RuleId ruleId) async {
    final Rule rule = findRule(ruleId);
    await executeNodeCommand(
      _channel,
      node.SetRuleEnabledCommand(ruleId: ruleId, enabled: true),
    );
    return _storeRule(rule.asEnabled());
  }

  @override
  Future<Rule> turnRuleOff(RuleId ruleId) async {
    final Rule rule = findRule(ruleId);
    await executeNodeCommand(
      _channel,
      node.SetRuleEnabledCommand(ruleId: ruleId, enabled: false),
    );
    return _storeRule(rule.asDisabled());
  }

  @override
  Future<void> deleteRule(RuleId ruleId) async {
    await executeNodeCommand(_channel, node.DeleteRuleCommand(ruleId: ruleId));

    _fetches.recordLocalChange();
    _rules = removeRecord(_rules, matches: (Rule rule) => rule.id == ruleId);
    notifyListeners();
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(_loadAfterWorkspaceChange);
    super.dispose();
  }

  void _loadAfterWorkspaceChange() {
    startBackgroundNodeWork(load);
  }

  Rule _storeRule(Rule rule) {
    _fetches.recordLocalChange();
    _rules = replaceOrAppendRecord(
      _rules,
      matches: (Rule candidate) => candidate.id == rule.id,
      record: rule,
    );
    notifyListeners();
    return rule;
  }

  Future<List<Rule>> _loadRules() async {
    final WorkspaceId? workspaceId = findCurrentWorkspaceId(
      _workspaceRepository,
    );
    if (workspaceId == null) {
      return const <Rule>[];
    }

    final List<node.Rule> rules = await executeNodeCommand(
      _channel,
      node.ListRulesCommand(workspaceId: workspaceId),
    );
    return List<Rule>.unmodifiable(<Rule>[
      for (final node.Rule rule in rules) mapRuleFromNode(rule),
    ]);
  }
}
