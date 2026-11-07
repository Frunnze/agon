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
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';

const String _skillKind = 'skill';
const Set<node.ChangeArea> _skillAreas = <node.ChangeArea>{
  node.ChangeArea.skills,
};

final class NodeBackedSkillRepository extends ChangeNotifier
    implements SkillRepository, NodeSynchronized {
  NodeBackedSkillRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository {
    _workspaceRepository.addListener(_loadAfterWorkspaceChange);
  }

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final FetchSequence _fetches = FetchSequence();
  List<Skill> _skills = const <Skill>[];

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final List<Skill> skills = await _loadSkills();
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    _skills = skills;
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    if (isChangeInAreas(topic, _skillAreas)) {
      await load();
    }
  }

  @override
  List<Skill> listSkills() => _skills;

  @override
  Skill findSkill(SkillId skillId) {
    return findRecord(
      _skills,
      matches: (Skill skill) => skill.id == skillId,
      kind: _skillKind,
      identifier: skillId.value,
    );
  }

  @override
  Future<Skill> createSkill(SkillDraft draft) async {
    requireValidSkillName(draft.name);
    requireFreeSkillName(name: draft.name, otherSkills: _skills);

    final node.Skill created = await executeNodeCommand(
      _channel,
      node.CreateSkillCommand(
        workspaceId: _workspaceRepository.currentWorkspace().id,
        skillName: draft.name,
        summary: draft.summary,
        instructions: draft.instructions,
        scope: mapScopeToNode(draft.scope),
        usage: mapSkillUsageToNode(draft.usage),
        improvement: mapSkillImprovementToNode(draft.improvement),
      ),
    );
    return _storeSkill(mapSkillFromNode(created));
  }

  @override
  Future<Skill> updateSkill(SkillId skillId, SkillDraft draft) async {
    requireValidSkillName(draft.name);
    final List<Skill> otherSkills = removeRecord(
      _skills,
      matches: (Skill skill) => skill.id == skillId,
    );
    requireFreeSkillName(name: draft.name, otherSkills: otherSkills);

    final node.Skill updated = await executeNodeCommand(
      _channel,
      node.UpdateSkillCommand(
        workspaceId: _workspaceRepository.currentWorkspace().id,
        skillId: skillId,
        skillName: draft.name,
        summary: draft.summary,
        instructions: draft.instructions,
        scope: mapScopeToNode(draft.scope),
        usage: mapSkillUsageToNode(draft.usage),
        improvement: mapSkillImprovementToNode(draft.improvement),
      ),
    );
    return _storeSkill(mapSkillFromNode(updated));
  }

  @override
  Future<Skill> undoLatestAgentChange(SkillId skillId) async {
    final node.Skill restored = await executeNodeCommand(
      _channel,
      node.UndoSkillChangeCommand(skillId: skillId),
    );
    return _storeSkill(mapSkillFromNode(restored));
  }

  @override
  Future<void> deleteSkill(SkillId skillId) async {
    await executeNodeCommand(
      _channel,
      node.DeleteSkillCommand(skillId: skillId),
    );

    _fetches.recordLocalChange();
    _skills = removeRecord(
      _skills,
      matches: (Skill skill) => skill.id == skillId,
    );
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

  Skill _storeSkill(Skill skill) {
    _fetches.recordLocalChange();
    _skills = replaceOrAppendRecord(
      _skills,
      matches: (Skill candidate) => candidate.id == skill.id,
      record: skill,
    );
    notifyListeners();
    return skill;
  }

  Future<List<Skill>> _loadSkills() async {
    final WorkspaceId? workspaceId = findCurrentWorkspaceId(
      _workspaceRepository,
    );
    if (workspaceId == null) {
      return const <Skill>[];
    }

    final List<node.Skill> skills = await executeNodeCommand(
      _channel,
      node.ListSkillsCommand(workspaceId: workspaceId),
    );
    return List<Skill>.unmodifiable(<Skill>[
      for (final node.Skill skill in skills) mapSkillFromNode(skill),
    ]);
  }
}
