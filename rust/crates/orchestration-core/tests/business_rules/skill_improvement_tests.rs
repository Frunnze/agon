use orchestration_core::library::{Skill, SkillImprovement};
use orchestration_core::skill_improvement::{
    SkillImprovementProposal, describe_instruction_change,
    parse_skill_improvements,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::skill_samples::{improvement, instruction_text, skill_named};

fn block(skill_name: &str, instructions: &str) -> String {
    format!(
        "SKILL IMPROVEMENT: {skill_name}\n{instructions}\n\
         END SKILL IMPROVEMENT"
    )
}

fn proposal<'skill>(
    skill: &'skill Skill,
    instructions: &str,
) -> SkillImprovementProposal<'skill> {
    SkillImprovementProposal {
        skill,
        instructions: instructions.to_owned(),
    }
}

#[test]
fn a_well_formed_block_proposes_its_instructions() {
    let skill = skill_named(1, "release", SkillImprovement::AskMe);
    let message = format!(
        "Done.\n\n{}\nOUTCOME: approved",
        block("release", "Build.\nSign.\nUpload.")
    );

    let proposals = parse_skill_improvements(&message, &[&skill]);

    assert_eq!(proposals, vec![proposal(&skill, "Build.\nSign.\nUpload.")]);
}

#[test]
fn a_block_without_its_end_line_proposes_nothing() {
    let skill = skill_named(1, "release", SkillImprovement::Auto);
    let message = "Done.\nSKILL IMPROVEMENT: release\nBuild twice.";

    let proposals = parse_skill_improvements(message, &[&skill]);

    assert_eq!(proposals, Vec::new());
}

#[test]
fn a_block_cut_short_by_the_next_block_is_dropped() {
    let skill = skill_named(1, "release", SkillImprovement::Auto);
    let other = skill_named(2, "testing", SkillImprovement::Auto);
    let message = format!(
        "SKILL IMPROVEMENT: release\nBuild twice.\n{}",
        block("testing", "Run every test.")
    );

    let proposals = parse_skill_improvements(&message, &[&skill, &other]);

    assert_eq!(proposals, vec![proposal(&other, "Run every test.")]);
}

#[test]
fn a_block_for_an_unknown_skill_proposes_nothing() {
    let skill = skill_named(1, "release", SkillImprovement::Auto);
    let message = block("deploy", "Deploy on Fridays.");

    let proposals = parse_skill_improvements(&message, &[&skill]);

    assert_eq!(proposals, Vec::new());
}

#[test]
fn a_block_for_a_skill_set_to_never_proposes_nothing() {
    let skill = skill_named(1, "release", SkillImprovement::Never);
    let message = block("release", "Build twice.");

    let proposals = parse_skill_improvements(&message, &[&skill]);

    assert_eq!(proposals, Vec::new());
}

#[test]
fn only_the_first_block_for_a_skill_counts() {
    let skill = skill_named(1, "release", SkillImprovement::AskMe);
    let message = format!(
        "{}\n{}",
        block("release", "First idea."),
        block("release", "Second idea.")
    );

    let proposals = parse_skill_improvements(&message, &[&skill]);

    assert_eq!(proposals, vec![proposal(&skill, "First idea.")]);
}

#[test]
fn a_block_that_changes_nothing_or_is_empty_proposes_nothing() {
    let skill = skill_named(1, "release", SkillImprovement::AskMe);
    let message = format!(
        "{}\n{}",
        block("release", &skill.instructions),
        block("release", "  ")
    );

    let proposals = parse_skill_improvements(&message, &[&skill]);

    assert_eq!(proposals, Vec::new());
}

#[test]
fn describes_how_many_lines_change() {
    let summary =
        describe_instruction_change("Build.\nSign.", "Build.\nTest.");

    assert_eq!(summary, "1 line added, 1 line removed");
}

proptest! {
    #[test]
    fn test_parse_skill_improvements_property_proposes_only_improvable_skills(
        settings in vec(improvement(), 1..5),
        new_texts in vec(instruction_text(), 5),
        filler in "[A-Za-z ,.]{0,40}",
    ) {
        let mut skills = Vec::new();
        for (index, setting) in settings.iter().enumerate() {
            let number = u128::try_from(index).unwrap_or_default();
            let name = format!("skill-{index}");
            skills.push(skill_named(number, &name, *setting));
        }
        let mut message = filler.clone();
        for (skill, new_text) in skills.iter().zip(&new_texts) {
            message.push('\n');
            message.push_str(&block(&skill.name, new_text));
        }
        let skill_references: Vec<&Skill> = skills.iter().collect();

        let proposals = parse_skill_improvements(&message, &skill_references);

        let mut expected = Vec::new();
        for (skill, new_text) in skills.iter().zip(&new_texts) {
            let is_improvable = skill.improvement != SkillImprovement::Never;
            let is_changed = new_text.trim() != skill.instructions;
            if is_improvable && is_changed {
                expected.push(proposal(skill, new_text.trim()));
            }
        }
        prop_assert_eq!(proposals, expected);
    }

    #[test]
    fn test_parse_skill_improvements_property_ignores_messages_without_blocks(
        message in "[A-Za-z0-9 ,.:\n]{0,200}",
        setting in improvement(),
    ) {
        let skill = skill_named(1, "release", setting);
        prop_assume!(!message.contains("SKILL IMPROVEMENT"));

        let proposals = parse_skill_improvements(&message, &[&skill]);

        prop_assert_eq!(proposals, Vec::new());
    }

    #[test]
    fn test_describe_instruction_change_property_counts_appended_lines(
        previous in instruction_text(),
        appended_count in 1_usize..6,
    ) {
        let mut proposed_lines = vec![previous.clone()];
        for index in 0..appended_count {
            proposed_lines.push(format!("New step {index}."));
        }
        let proposed = proposed_lines.join("\n");

        let summary = describe_instruction_change(&previous, &proposed);

        let noun = if appended_count == 1 { "line" } else { "lines" };
        let expected =
            format!("{appended_count} {noun} added, 0 lines removed");
        prop_assert_eq!(summary, expected);
    }
}
