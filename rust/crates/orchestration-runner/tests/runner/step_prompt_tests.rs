use orchestration_core::identifiers::SkillId;
use orchestration_core::library::{Skill, SkillSource, SkillUsage};
use orchestration_core::scope::Scope;
use orchestration_runner::step_prompt::{UpstreamResult, compose_step_prompt};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

fn skill_with(name: &str, instructions: &str) -> Skill {
    Skill {
        id: SkillId(Uuid::from_u128(1)),
        name: name.to_string(),
        summary: String::new(),
        instructions: instructions.to_string(),
        scope: Scope::everywhere(),
        usage: SkillUsage::WhenChosen,
        source: SkillSource::BuiltIn,
    }
}

fn any_part() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9][a-zA-Z0-9 .,]{0,30}"
}

#[test]
fn composes_every_part_under_its_heading() {
    let skill = skill_with("release-ios", "Use fastlane.");
    let upstream = UpstreamResult {
        step_name: "plan".to_string(),
        final_message: "Ship version 2.".to_string(),
    };

    let prompt = compose_step_prompt(
        "Build the app",
        "Fix the signing error.",
        &[&skill],
        &[upstream],
    );

    let expected = "Build the app\n\n\
        ## Task details\nFix the signing error.\n\n\
        ## Skill: release-ios\nUse fastlane.\n\n\
        ## Result from plan\nShip version 2.";
    assert_eq!(prompt, expected);
}

proptest! {
    #[test]
    fn test_compose_step_prompt_property_keeps_every_part_in_order(
        instruction in any_part(),
        details in any_part(),
        skill_parts in vec((any_part(), any_part()), 0..3),
        upstream_parts in vec((any_part(), any_part()), 0..3),
    ) {
        let skills: Vec<Skill> = skill_parts
            .iter()
            .map(|(name, instructions)| skill_with(name, instructions))
            .collect();
        let skill_references: Vec<&Skill> = skills.iter().collect();
        let upstream_results: Vec<UpstreamResult> = upstream_parts
            .iter()
            .map(|(step_name, final_message)| UpstreamResult {
                step_name: step_name.clone(),
                final_message: final_message.clone(),
            })
            .collect();

        let prompt = compose_step_prompt(
            &instruction,
            &details,
            &skill_references,
            &upstream_results,
        );

        prop_assert!(prompt.starts_with(&instruction));
        let mut searched_from = instruction.len();
        let mut expected_parts = vec![details.clone()];
        for skill in &skills {
            expected_parts.push(skill.instructions.clone());
        }
        for upstream in &upstream_results {
            expected_parts.push(upstream.final_message.clone());
        }
        for part in expected_parts {
            let rest = &prompt[searched_from..];
            let found = rest.find(&part);
            prop_assert!(found.is_some());
            searched_from += found.unwrap_or_default() + part.len();
        }
    }

    #[test]
    fn test_compose_step_prompt_property_never_panics_on_any_text(
        instruction in any::<String>(),
        details in any::<String>(),
        final_message in any::<String>(),
    ) {
        let upstream = UpstreamResult {
            step_name: "plan".to_string(),
            final_message: final_message.clone(),
        };

        let prompt =
            compose_step_prompt(&instruction, &details, &[], &[upstream]);

        prop_assert!(prompt.ends_with(&final_message));
        if !instruction.trim().is_empty() {
            prop_assert!(prompt.starts_with(&instruction));
        }
    }
}
