import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';

abstract interface class SkillRepository implements Listenable {
  List<Skill> listSkills();

  Skill findSkill(SkillId skillId);

  Future<Skill> createSkill(SkillDraft draft);

  Future<Skill> updateSkill(SkillId skillId, SkillDraft draft);

  Future<void> deleteSkill(SkillId skillId);

  Future<Skill> undoLatestAgentChange(SkillId skillId);
}
