import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/current_workspace_records.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/scope_cleanup.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';
import 'package:agent_orchestration/data/rules/skill_undo.dart';

const String _skillKind = 'skill';
const String _createdSkillPrefix = 'created-skill-';
const int _keptSkillChanges = 20;

final class FakeSkillRepository extends ChangeNotifier
    implements SkillRepository {
  FakeSkillRepository({
    required List<Skill> skills,
    required Clock clock,
    required WorkspaceRepository workspaceRepository,
  }) : _skills = List<Skill>.unmodifiable(skills),
       _clock = clock,
       _workspaceRepository = workspaceRepository {
    _workspaceRepository.addListener(notifyListeners);
  }

  final Clock _clock;
  final WorkspaceRepository _workspaceRepository;
  List<Skill> _skills;
  int _createdSkillCount = 0;
  FakeTaskRepository? _taskRepository;

  void linkTasks(FakeTaskRepository taskRepository) {
    _taskRepository = taskRepository;
  }

  @override
  List<Skill> listSkills() {
    return listRecordsInCurrentWorkspace(
      records: _skills,
      workspaceRepository: _workspaceRepository,
      readWorkspaceScope: _readWorkspaceScope,
    );
  }

  @override
  Skill findSkill(SkillId skillId) {
    return findRecord(
      listSkills(),
      matches: (Skill skill) => skill.id == skillId,
      kind: _skillKind,
      identifier: skillId.value,
    );
  }

  @override
  Future<Skill> createSkill(SkillDraft draft) async {
    requireValidSkillName(draft.name);
    requireFreeSkillName(name: draft.name, otherSkills: listSkills());

    final Skill skill = Skill(
      id: _nextFreeSkillId(),
      name: draft.name,
      summary: draft.summary,
      instructions: draft.instructions,
      scope: draft.scope,
      usage: draft.usage,
      source: SkillSource.created,
      improvement: draft.improvement,
      history: const <SkillChange>[],
    );

    _skills = appendRecord(_skills, skill);
    notifyListeners();
    return skill;
  }

  @override
  Future<Skill> updateSkill(SkillId skillId, SkillDraft draft) async {
    requireValidSkillName(draft.name);
    final Skill original = findSkill(skillId);
    final List<Skill> otherSkills = removeRecord(
      listSkills(),
      matches: (Skill skill) => skill.id == skillId,
    );
    requireFreeSkillName(name: draft.name, otherSkills: otherSkills);

    final bool hasNewInstructions =
        draft.instructions != original.instructions;
    final List<SkillChange> history = hasNewInstructions
        ? _keepLatestChanges(<SkillChange>[
            ...original.history,
            SkillChange(
              origin: const PersonEdit(),
              savedAt: _clock.now(),
              replacedInstructions: original.instructions,
            ),
          ])
        : original.history;
    final Skill updated = Skill(
      id: skillId,
      name: draft.name,
      summary: draft.summary,
      instructions: draft.instructions,
      scope: draft.scope,
      usage: draft.usage,
      source: original.source,
      improvement: draft.improvement,
      history: history,
    );

    return _replaceSkill(updated);
  }

  @override
  Future<void> deleteSkill(SkillId skillId) async {
    findSkill(skillId);

    _removeSkills(<SkillId>{skillId});
  }

  @override
  Future<Skill> undoLatestAgentChange(SkillId skillId) async {
    final Skill skill = findSkill(skillId);
    final List<SkillChange> history = skill.history;
    final SkillChange? agentChange = findUndoableAgentChange(history);
    if (agentChange == null) {
      throw StateError('No agent made the latest change to ${skill.name}');
    }

    final Skill restored = Skill(
      id: skill.id,
      name: skill.name,
      summary: skill.summary,
      instructions: agentChange.replacedInstructions,
      scope: skill.scope,
      usage: skill.usage,
      source: skill.source,
      improvement: skill.improvement,
      history: history.sublist(0, history.length - 1),
    );
    return _replaceSkill(restored);
  }

  void forgetWorkspace({
    required WorkspaceId deletedWorkspaceId,
    required Set<WorkspaceId> remainingWorkspaceIds,
  }) {
    final List<Skill> rescopedSkills = <Skill>[
      for (final Skill skill in _skills)
        _withScope(
          skill,
          forgetWorkspaceInScope(skill.scope, deletedWorkspaceId),
        ),
    ];
    final Set<SkillId> unseenSkillIds = <SkillId>{
      for (final Skill skill in rescopedSkills)
        if (isSeenInNoWorkspace(skill.scope.workspaces, remainingWorkspaceIds))
          skill.id,
    };

    _skills = List<Skill>.unmodifiable(rescopedSkills);
    _removeSkills(unseenSkillIds);
  }

  void forgetProjects(Set<ProjectId> deletedProjectIds) {
    _skills = List<Skill>.unmodifiable(<Skill>[
      for (final Skill skill in _skills)
        _withScope(
          skill,
          forgetProjectsInScope(skill.scope, deletedProjectIds),
        ),
    ]);
    notifyListeners();
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(notifyListeners);
    super.dispose();
  }

  SkillId _nextFreeSkillId() {
    while (true) {
      _createdSkillCount += 1;
      final SkillId candidate = SkillId(
        '$_createdSkillPrefix$_createdSkillCount',
      );
      final bool isTaken = _skills.any((Skill skill) => skill.id == candidate);
      if (!isTaken) {
        return candidate;
      }
    }
  }

  void _removeSkills(Set<SkillId> removedSkillIds) {
    _skills = removeRecord(
      _skills,
      matches: (Skill skill) => removedSkillIds.contains(skill.id),
    );
    _taskRepository?.forgetSkills(removedSkillIds);
    notifyListeners();
  }

  Skill _replaceSkill(Skill replacement) {
    _skills = replaceRecord(
      _skills,
      matches: (Skill skill) => skill.id == replacement.id,
      replacement: replacement,
    );
    notifyListeners();
    return replacement;
  }
}

List<SkillChange> _keepLatestChanges(List<SkillChange> history) {
  final int excess = history.length - _keptSkillChanges;
  if (excess <= 0) {
    return history;
  }
  return history.sublist(excess);
}

WorkspaceScope _readWorkspaceScope(Skill skill) => skill.scope.workspaces;

Skill _withScope(Skill skill, Scope scope) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: scope,
    usage: skill.usage,
    source: skill.source,
    improvement: skill.improvement,
    history: skill.history,
  );
}
