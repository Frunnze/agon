import 'support/reply_race_properties.dart';
import 'support/skill_reply_race.dart';

const List<ReplyRaceStep<SkillReplyRace>> _elsewhereSteps =
    <ReplyRaceStep<SkillReplyRace>>[
      addSkillElsewhere,
      editSkillElsewhere,
      deleteSkillElsewhere,
    ];

const List<ReplyRaceCase<SkillReplyRace>> _raceCases =
    <ReplyRaceCase<SkillReplyRace>>[
      ReplyRaceCase<SkillReplyRace>(
        testedName: 'node_backed_skill_repository_create_skill',
        seed: 81101,
        localSteps: <ReplyRaceStep<SkillReplyRace>>[createRaceSkill],
        elsewhereSteps: _elsewhereSteps,
      ),
      ReplyRaceCase<SkillReplyRace>(
        testedName: 'node_backed_skill_repository_update_skill',
        seed: 81111,
        localSteps: <ReplyRaceStep<SkillReplyRace>>[
          updateRaceSkill,
          createRaceSkill,
        ],
        elsewhereSteps: _elsewhereSteps,
      ),
      ReplyRaceCase<SkillReplyRace>(
        testedName: 'node_backed_skill_repository_undo_latest_agent_change',
        seed: 81121,
        localSteps: <ReplyRaceStep<SkillReplyRace>>[undoRaceSkillChange],
        elsewhereSteps: _elsewhereSteps,
      ),
      ReplyRaceCase<SkillReplyRace>(
        testedName: 'node_backed_skill_repository_delete_skill',
        seed: 81131,
        localSteps: <ReplyRaceStep<SkillReplyRace>>[
          deleteRaceSkill,
          createRaceSkill,
        ],
        elsewhereSteps: _elsewhereSteps,
      ),
      ReplyRaceCase<SkillReplyRace>(
        testedName: 'node_backed_skill_repository_store_skill',
        seed: 81141,
        localSteps: <ReplyRaceStep<SkillReplyRace>>[
          createRaceSkill,
          updateRaceSkill,
          undoRaceSkillChange,
          deleteRaceSkill,
        ],
        elsewhereSteps: <ReplyRaceStep<SkillReplyRace>>[
          ..._elsewhereSteps,
          switchSkillRaceWorkspace,
        ],
      ),
    ];

void main() {
  for (final ReplyRaceCase<SkillReplyRace> raceCase in _raceCases) {
    registerReplyRaceProperties(
      openRace: openSkillReplyRace,
      raceCase: raceCase,
    );
  }
}
