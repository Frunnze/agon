use orchestration_core::library::{
    Skill, SkillChangeOrigin, SkillImprovement,
};
use orchestration_core::skill_history::{
    KEPT_SKILL_CHANGES, SkillUndoProblem, record_skill_change,
    undo_latest_agent_change,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::skill_samples::{
    agent_origin, any_origin, improvement, instruction_text, saved_at,
    skill_named,
};

const MOST_CHANGES: usize = 30;
const SKILL_NAME: &str = "release";
const MOST_OFFSET_SECONDS: i64 = 1_000;

fn without_text(skill: &Skill) -> Skill {
    Skill {
        instructions: String::new(),
        history: Vec::new(),
        ..skill.clone()
    }
}

fn offset_of(index: usize) -> i64 {
    i64::try_from(index).unwrap_or_default()
}

proptest! {
    #[test]
    fn test_record_skill_change_property_keeps_every_other_skill_field(
        number in any::<u128>(),
        setting in improvement(),
        new_instructions in instruction_text(),
        origin in any_origin(),
        offset in 0..MOST_OFFSET_SECONDS,
    ) {
        let skill = skill_named(number, SKILL_NAME, setting);

        let moment = saved_at(offset);
        let changed =
            record_skill_change(&skill, &new_instructions, origin, moment);

        prop_assert_eq!(without_text(&changed), without_text(&skill));
        prop_assert_eq!(&changed.instructions, &new_instructions);
        let newest = changed
            .history
            .last()
            .ok_or_else(|| TestCaseError::fail("a change was recorded"))?;
        prop_assert_eq!(newest.origin, origin);
        prop_assert_eq!(newest.saved_at, saved_at(offset));
        prop_assert_eq!(&newest.replaced_instructions, &skill.instructions);
    }

    #[test]
    fn test_undo_latest_agent_change_property_undoes_newest_first(
        changes in vec((instruction_text(), agent_origin()), 0..MOST_CHANGES),
    ) {
        let original = skill_named(5, SKILL_NAME, SkillImprovement::Auto);
        let mut versions: Vec<String> = vec![original.instructions.clone()];
        let mut skill = original;
        for (index, (instructions, origin)) in changes.iter().enumerate() {
            let moment = saved_at(offset_of(index));
            skill = record_skill_change(&skill, instructions, *origin, moment);
            versions.push(instructions.clone());
        }

        let undoable_count = changes.len().min(KEPT_SKILL_CHANGES);
        for step in 1..=undoable_count {
            skill = undo_latest_agent_change(&skill)
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
            let expected = &versions[versions.len() - 1 - step];
            prop_assert_eq!(&skill.instructions, expected);
        }
        let past_the_history = undo_latest_agent_change(&skill);
        let nothing_left = Err(SkillUndoProblem::NoAgentChange);
        prop_assert_eq!(past_the_history, nothing_left);
    }

    #[test]
    fn test_undo_latest_agent_change_property_drops_only_the_newest_entry(
        changes in vec((instruction_text(), any_origin()), 1..MOST_CHANGES),
        setting in improvement(),
    ) {
        let mut skill = skill_named(6, SKILL_NAME, setting);
        for (index, (instructions, origin)) in changes.iter().enumerate() {
            let moment = saved_at(offset_of(index));
            skill = record_skill_change(&skill, instructions, *origin, moment);
        }

        let undone = undo_latest_agent_change(&skill);

        let newest_origin = skill.history.last().map(|change| change.origin);
        let person_edit = Some(SkillChangeOrigin::PersonEdit);
        prop_assert_eq!(undone.is_err(), newest_origin == person_edit);
        if let Ok(undone_skill) = undone {
            let kept_count = skill.history.len() - 1;
            let kept_history = &skill.history[..kept_count];
            prop_assert_eq!(&undone_skill.history[..], kept_history);
            let unchanged = without_text(&skill);
            prop_assert_eq!(without_text(&undone_skill), unchanged);
        }
    }
}
