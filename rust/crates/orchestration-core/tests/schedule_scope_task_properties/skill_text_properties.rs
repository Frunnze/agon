use orchestration_core::library::{Skill, SkillImprovement};
use orchestration_core::skill_improvement::{
    SKILL_IMPROVEMENT_END, SKILL_IMPROVEMENT_START,
    describe_instruction_change, parse_skill_improvements,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::skill_samples::{improvement, instruction_text, skill_named};

const MOST_SKILLS: usize = 5;
const MOST_LINES: usize = 8;
const MOST_BLANK_LINES: usize = 3;
const MOST_COUNTED_LINES: usize = 24;
const SKILL_NAME: &str = "release";
const UNKNOWN_SKILL_NAME: &str = "unknown";

fn block_lines(skill_name: &str, lines: &[String]) -> Vec<String> {
    let mut message_lines =
        vec![format!("{SKILL_IMPROVEMENT_START} {skill_name}")];
    message_lines.extend(lines.iter().cloned());
    message_lines.push(SKILL_IMPROVEMENT_END.to_owned());
    message_lines
}

fn proposed_text(message: &str, skill: &Skill) -> Option<String> {
    let proposals = parse_skill_improvements(message, &[skill]);
    proposals
        .into_iter()
        .next()
        .map(|proposal| proposal.instructions)
}

fn instruction_line() -> impl Strategy<Value = String> {
    "[ \t]{0,3}[a-z]{1,6}( [a-z]{1,6}){0,2}"
}

fn blank_line() -> impl Strategy<Value = String> {
    "[ \t]{0,3}"
}

fn read_counts(summary: &str) -> Option<(usize, usize)> {
    let (added_part, removed_part) = summary.split_once(", ")?;
    let added_number = added_part.split(' ').next()?.parse().ok()?;
    let removed_number = removed_part.split(' ').next()?.parse().ok()?;
    Some((added_number, removed_number))
}

fn line_count(text: &str) -> usize {
    text.lines().count()
}

fn numbered_lines(count: usize) -> String {
    let mut lines: Vec<String> = Vec::new();
    for index in 0..count {
        lines.push(format!("step {index}"));
    }
    lines.join("\n")
}

fn expected_count_text(count: usize, verb: &str) -> String {
    if count == 1 {
        return format!("1 line {verb}");
    }
    format!("{count} lines {verb}")
}

proptest! {
    #[test]
    fn test_close_block_property_trims_surrounding_blank_lines(
        setting in prop_oneof![
            Just(SkillImprovement::AskMe),
            Just(SkillImprovement::Auto),
        ],
        before in vec(blank_line(), 0..MOST_BLANK_LINES),
        lines in vec(instruction_line(), 1..MOST_LINES),
        after in vec(blank_line(), 0..MOST_BLANK_LINES),
    ) {
        let skill = skill_named(1, SKILL_NAME, setting);
        let mut padded = before;
        padded.extend(lines.iter().cloned());
        padded.extend(after);
        let message = block_lines(SKILL_NAME, &padded).join("\n");

        let proposed = proposed_text(&message, &skill);

        let expected = lines.join("\n").trim().to_owned();
        prop_assert_eq!(proposed, Some(expected));
    }

    #[test]
    fn test_close_block_property_keeps_inner_indentation(
        first_line in "[a-z]{1,6}",
        inner_lines in vec(instruction_line(), 0..MOST_LINES),
        last_line in "[a-z]{1,6}",
    ) {
        let skill = skill_named(1, SKILL_NAME, SkillImprovement::Auto);
        let mut lines = vec![first_line];
        lines.extend(inner_lines);
        lines.push(last_line);
        let message = block_lines(SKILL_NAME, &lines).join("\n");

        let expected = Some(lines.join("\n"));
        prop_assert_eq!(proposed_text(&message, &skill), expected);
    }

    #[test]
    fn test_close_block_property_reads_windows_line_endings(
        lines in vec("[a-z]{1,6}( [a-z]{1,6}){0,2}", 1..MOST_LINES),
    ) {
        let skill = skill_named(1, SKILL_NAME, SkillImprovement::AskMe);
        let message_lines = block_lines(SKILL_NAME, &lines);

        let from_windows = proposed_text(&message_lines.join("\r\n"), &skill);
        let from_unix = proposed_text(&message_lines.join("\n"), &skill);

        prop_assert_eq!(&from_windows, &from_unix);
        let has_carriage_return = from_windows
            .is_some_and(|text| text.contains('\r'));
        prop_assert!(!has_carriage_return);
    }

    #[test]
    fn test_find_improvable_skill_property_follows_the_skill_setting(
        setting in improvement(),
        text in instruction_text(),
    ) {
        let skill = skill_named(1, SKILL_NAME, setting);
        let text_lines = std::slice::from_ref(&text);
        let message = block_lines(SKILL_NAME, text_lines).join("\n");

        let proposed = proposed_text(&message, &skill);

        let is_improvable = setting != SkillImprovement::Never;
        let is_changed = text.trim() != skill.instructions;
        prop_assert_eq!(proposed.is_some(), is_improvable && is_changed);
    }

    #[test]
    fn test_find_improvable_skill_property_ignores_unknown_names(
        settings in vec(improvement(), 0..MOST_SKILLS),
        text in instruction_text(),
    ) {
        let mut skills: Vec<Skill> = Vec::new();
        for (index, setting) in settings.iter().enumerate() {
            let number = u128::try_from(index).unwrap_or_default();
            let name = format!("skill-{index}");
            skills.push(skill_named(number, &name, *setting));
        }
        let skill_references: Vec<&Skill> = skills.iter().collect();
        let message = block_lines(UNKNOWN_SKILL_NAME, &[text]).join("\n");

        let proposals = parse_skill_improvements(&message, &skill_references);

        prop_assert!(proposals.is_empty());
    }

    #[test]
    fn test_find_improvable_skill_property_picks_the_named_skill(
        count in 1..MOST_SKILLS,
        chosen in any::<prop::sample::Index>(),
        text in "[a-z]{1,6}( [a-z]{1,6}){0,3}",
    ) {
        let mut skills: Vec<Skill> = Vec::new();
        for index in 0..count {
            let number = u128::try_from(index).unwrap_or_default();
            let name = format!("skill-{index}");
            skills.push(skill_named(number, &name, SkillImprovement::Auto));
        }
        let wanted = chosen.get(&skills);
        let skill_references: Vec<&Skill> = skills.iter().collect();
        let message = block_lines(&wanted.name, &[text]).join("\n");

        let proposals = parse_skill_improvements(&message, &skill_references);

        let proposed_ids: Vec<_> =
            proposals.iter().map(|proposal| proposal.skill.id).collect();
        prop_assert_eq!(proposed_ids, vec![wanted.id]);
    }

    #[test]
    fn test_describe_instruction_change_property_same_text_changes_nothing(
        text in instruction_text(),
    ) {
        let summary = describe_instruction_change(&text, &text);

        prop_assert_eq!(summary, "0 lines added, 0 lines removed");
    }

    #[test]
    fn test_describe_instruction_change_property_counts_balance_line_totals(
        current in instruction_text(),
        proposed in instruction_text(),
    ) {
        let forward = describe_instruction_change(&current, &proposed);
        let backward = describe_instruction_change(&proposed, &current);

        let (added, removed) = read_counts(&forward)
            .ok_or_else(|| TestCaseError::fail(forward.clone()))?;
        let swapped = read_counts(&backward)
            .ok_or_else(|| TestCaseError::fail(backward.clone()))?;
        prop_assert_eq!(swapped, (removed, added));
        let growth = line_count(&proposed) + removed;
        prop_assert_eq!(growth, line_count(&current) + added);
    }

    #[test]
    fn test_count_lines_property_one_line_is_singular(
        text in "[a-z]{1,8}",
    ) {
        let summary = describe_instruction_change("", &text);

        prop_assert_eq!(summary, "1 line added, 0 lines removed");
    }

    #[test]
    fn test_count_lines_property_other_counts_are_plural(
        count in 0..MOST_COUNTED_LINES,
    ) {
        let lines = numbered_lines(count);

        let summary = describe_instruction_change("", &lines);

        let expected = format!(
            "{}, 0 lines removed",
            expected_count_text(count, "added")
        );
        prop_assert_eq!(summary, expected);
    }

    #[test]
    fn test_count_lines_property_counts_every_removed_line(
        count in 0..MOST_COUNTED_LINES,
    ) {
        let lines = numbered_lines(count);

        let summary = describe_instruction_change(&lines, "");

        let expected = format!(
            "0 lines added, {}",
            expected_count_text(count, "removed")
        );
        prop_assert_eq!(summary, expected);
    }
}
