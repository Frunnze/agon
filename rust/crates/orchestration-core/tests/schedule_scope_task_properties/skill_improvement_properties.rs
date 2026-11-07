use std::collections::BTreeSet;

use orchestration_core::library::{Skill, SkillImprovement};
use orchestration_core::skill_improvement::{
    SKILL_IMPROVEMENT_END, SKILL_IMPROVEMENT_START, parse_skill_improvements,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::skill_samples::{improvement, instruction_text, skill_named};

const MOST_SKILLS: usize = 4;
const MOST_BLOCKS: usize = 6;

fn block(skill_name: &str, instructions: &str) -> String {
    format!(
        "{SKILL_IMPROVEMENT_START} {skill_name}\n{instructions}\n\
         {SKILL_IMPROVEMENT_END}"
    )
}

fn skill_list(settings: &[SkillImprovement]) -> Vec<Skill> {
    let mut skills: Vec<Skill> = Vec::new();
    for (index, setting) in settings.iter().enumerate() {
        let number = u128::try_from(index).unwrap_or_default();
        skills.push(skill_named(number, &format!("skill-{index}"), *setting));
    }
    skills
}

fn improvable_setting() -> impl Strategy<Value = SkillImprovement> {
    prop_oneof![Just(SkillImprovement::AskMe), Just(SkillImprovement::Auto)]
}

fn noise_line() -> impl Strategy<Value = String> {
    "[A-Za-z0-9 ,.:]{0,30}"
}

fn proposed_texts(message: &str, skill: &Skill) -> Vec<String> {
    let proposals = parse_skill_improvements(message, &[skill]);
    let mut texts: Vec<String> = Vec::new();
    for proposal in proposals {
        texts.push(proposal.instructions);
    }
    texts
}

proptest! {
    #[test]
    fn test_parse_skill_improvements_property_proposes_each_skill_once(
        settings in vec(improvement(), 1..MOST_SKILLS),
        blocks in vec((any::<prop::sample::Index>(), instruction_text()),
            0..MOST_BLOCKS),
    ) {
        let skills = skill_list(&settings);
        let mut message = String::new();
        for (skill_index, text) in &blocks {
            let skill = skill_index.get(&skills);
            message.push_str(&block(&skill.name, text));
            message.push('\n');
        }
        let skill_references: Vec<&Skill> = skills.iter().collect();

        let proposals = parse_skill_improvements(&message, &skill_references);

        let mut proposed_ids = BTreeSet::new();
        for proposal in &proposals {
            prop_assert!(proposed_ids.insert(proposal.skill.id));
            let skill = proposal.skill;
            prop_assert_ne!(skill.improvement, SkillImprovement::Never);
            prop_assert!(!proposal.instructions.is_empty());
            let trimmed = proposal.instructions.trim();
            prop_assert_eq!(trimmed, &proposal.instructions);
            prop_assert_ne!(&proposal.instructions, skill.instructions.trim());
            let was_written = blocks.iter().any(|(skill_index, text)| {
                skill_index.get(&skills).id == skill.id
                    && text.trim() == proposal.instructions
            });
            prop_assert!(was_written);
        }
    }

    #[test]
    fn test_read_improvement_blocks_property_reads_every_closed_block(
        settings in vec(improvable_setting(), 1..MOST_SKILLS),
        texts in vec("[a-z]{1,6}( [a-z]{1,6}){0,3}", MOST_SKILLS),
        noise in vec(noise_line(), MOST_SKILLS + 1),
    ) {
        let skills = skill_list(&settings);
        let mut message = noise[0].clone();
        for ((skill, text), noise_after) in
            skills.iter().zip(&texts).zip(&noise[1..])
        {
            message.push('\n');
            message.push_str(&block(&skill.name, text));
            message.push('\n');
            message.push_str(noise_after);
        }
        let skill_references: Vec<&Skill> = skills.iter().collect();

        let proposals = parse_skill_improvements(&message, &skill_references);

        prop_assert_eq!(proposals.len(), skills.len());
        let expected_pairs = skills.iter().zip(&texts);
        for (proposal, (skill, text)) in proposals.iter().zip(expected_pairs) {
            prop_assert_eq!(proposal.skill.id, skill.id);
            prop_assert_eq!(&proposal.instructions, text);
        }
    }

    #[test]
    fn test_read_improvement_blocks_property_markers_allow_surrounding_space(
        setting in improvable_setting(),
        text in instruction_text(),
        before_start in "[ \t]{0,3}",
        after_colon in "[ \t]{0,3}",
        after_name in "[ \t]{0,3}",
        around_end in "[ \t]{0,3}",
    ) {
        let skill = skill_named(1, "release", setting);
        let plain = block(&skill.name, &text);
        let spaced = format!(
            "{before_start}{SKILL_IMPROVEMENT_START}{after_colon}release\
             {after_name}\n{text}\n{around_end}{SKILL_IMPROVEMENT_END}\
             {around_end}"
        );

        prop_assert_eq!(
            proposed_texts(&spaced, &skill),
            proposed_texts(&plain, &skill)
        );
    }

    #[test]
    fn test_read_improvement_blocks_property_ignores_unopened_and_unclosed(
        setting in improvable_setting(),
        text in instruction_text(),
        dangling in instruction_text(),
    ) {
        let skill = skill_named(1, "release", setting);
        let closed_only = block(&skill.name, &text);
        let message = format!(
            "{SKILL_IMPROVEMENT_END}\n{closed_only}\n\
             {SKILL_IMPROVEMENT_END}\n{SKILL_IMPROVEMENT_START} release\n\
             {dangling}"
        );

        prop_assert_eq!(
            proposed_texts(&message, &skill),
            proposed_texts(&closed_only, &skill)
        );
    }
}
