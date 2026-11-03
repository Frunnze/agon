import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';
import 'package:agent_orchestration/data/rules/skill_undo.dart';

const String _skillKind = 'skill';

final class FakeSkillRepository extends ChangeNotifier
    implements SkillRepository {
  FakeSkillRepository({required List<Skill> skills, required Clock clock})
    : _skills = List<Skill>.unmodifiable(skills),
      _clock = clock;

  final Clock _clock;
  List<Skill> _skills;
  int _createdSkillCount = 0;

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
    requireFreeSkillName(name: draft.name, otherSkills: _skills);

    _createdSkillCount += 1;
    final Skill skill = Skill(
      id: SkillId('created-skill-$_createdSkillCount'),
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
    final Skill original = findSkill(skillId);
    final List<Skill> otherSkills = removeRecord(
      _skills,
      matches: (Skill skill) => skill.id == skillId,
    );
    requireFreeSkillName(name: draft.name, otherSkills: otherSkills);

    final bool hasNewInstructions =
        draft.instructions != original.instructions;
    final List<SkillChange> history = hasNewInstructions
        ? <SkillChange>[
            ...original.history,
            SkillChange(
              origin: const PersonEdit(),
              savedAt: _clock.now(),
              replacedInstructions: original.instructions,
            ),
          ]
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

    _skills = removeRecord(
      _skills,
      matches: (Skill skill) => skill.id == skillId,
    );
    notifyListeners();
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
