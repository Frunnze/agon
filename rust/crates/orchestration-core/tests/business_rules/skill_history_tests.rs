use orchestration_core::library::{SkillChangeOrigin, SkillImprovement};
use orchestration_core::skill_history::{
    KEPT_SKILL_CHANGES, SkillUndoProblem, record_skill_change,
    undo_latest_agent_change,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::skill_samples::{
    agent_origin, any_origin, instruction_text, saved_at, skill_named,
};

#[test]
fn a_change_keeps_the_replaced_instructions_and_its_origin() {
    let skill = skill_named(1, "release", SkillImprovement::Auto);
    let origin = SkillChangeOrigin::PersonEdit;

    let changed =
        record_skill_change(&skill, "Ship it twice.", origin, saved_at(0));

    assert_eq!(changed.instructions, "Ship it twice.");
    assert_eq!(changed.history.len(), 1);
    assert_eq!(changed.history[0].origin, origin);
    assert_eq!(changed.history[0].saved_at, saved_at(0));
    assert_eq!(changed.history[0].replaced_instructions, skill.instructions);
}

#[test]
fn a_skill_without_changes_has_nothing_to_undo() {
    let skill = skill_named(1, "release", SkillImprovement::AskMe);

    let undone = undo_latest_agent_change(&skill);

    assert_eq!(undone, Err(SkillUndoProblem::NoAgentChange));
}

proptest! {
    #[test]
    fn test_record_skill_change_property_undo_restores_the_previous_skill(
        earlier_changes in vec((instruction_text(), any_origin()), 0..5),
        new_instructions in instruction_text(),
        origin in agent_origin(),
    ) {
        let mut skill = skill_named(2, "release", SkillImprovement::Auto);
        for (offset, (instructions, earlier)) in
            earlier_changes.iter().enumerate()
        {
            let moment = saved_at(i64::try_from(offset).unwrap_or_default());
            skill = record_skill_change(&skill, instructions, *earlier, moment);
        }

        let changed =
            record_skill_change(&skill, &new_instructions, origin, saved_at(9));
        let undone = undo_latest_agent_change(&changed);

        prop_assert_eq!(undone, Ok(skill));
    }

    #[test]
    fn test_record_skill_change_property_keeps_the_newest_changes_only(
        changes in vec((instruction_text(), any_origin()), 0..40),
    ) {
        let mut skill = skill_named(3, "release", SkillImprovement::AskMe);
        for (instructions, origin) in &changes {
            let moment = saved_at(0);
            skill = record_skill_change(&skill, instructions, *origin, moment);
        }

        let expected_length = changes.len().min(KEPT_SKILL_CHANGES);
        prop_assert_eq!(skill.history.len(), expected_length);
        if let Some((last_instructions, last_origin)) = changes.last() {
            prop_assert_eq!(&skill.instructions, last_instructions);
            let newest = skill.history.last().map(|change| change.origin);
            prop_assert_eq!(newest, Some(*last_origin));
        }
    }

    #[test]
    fn test_undo_latest_agent_change_property_never_undoes_a_person_edit(
        earlier_changes in vec((instruction_text(), any_origin()), 0..5),
        edited_instructions in instruction_text(),
    ) {
        let mut skill = skill_named(4, "release", SkillImprovement::Auto);
        for (instructions, origin) in &earlier_changes {
            let moment = saved_at(0);
            skill = record_skill_change(&skill, instructions, *origin, moment);
        }
        let edited = record_skill_change(
            &skill,
            &edited_instructions,
            SkillChangeOrigin::PersonEdit,
            saved_at(1),
        );

        let undone = undo_latest_agent_change(&edited);

        prop_assert_eq!(undone, Err(SkillUndoProblem::NoAgentChange));
    }
}
