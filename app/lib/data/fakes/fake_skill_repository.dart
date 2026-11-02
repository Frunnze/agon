import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';

const String _skillKind = 'skill';

final class FakeSkillRepository extends ChangeNotifier
    implements SkillRepository {
  FakeSkillRepository({required List<Skill> skills})
    : _skills = List<Skill>.unmodifiable(skills);

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

    final Skill updated = Skill(
      id: skillId,
      name: draft.name,
      summary: draft.summary,
      instructions: draft.instructions,
      scope: draft.scope,
      usage: draft.usage,
      source: original.source,
    );

    _skills = replaceRecord(
      _skills,
      matches: (Skill skill) => skill.id == skillId,
      replacement: updated,
    );
    notifyListeners();
    return updated;
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
}
