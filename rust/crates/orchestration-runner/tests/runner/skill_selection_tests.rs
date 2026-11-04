use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::{ProjectId, SkillId, WorkspaceId};
use orchestration_core::library::{
    Skill, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::workflow::AgentKind;
use orchestration_runner::skill_selection::select_step_skills;
use orchestration_runner::step_plan::StepPlan;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

const WORKSPACE_NUMBER: u128 = 0x1111;
const PROJECT_NUMBER: u128 = 0x2222;
const OTHER_PROJECT_NUMBER: u128 = 0x3333;

#[derive(Clone, Debug)]
struct SkillChoice {
    is_automatic: bool,
    is_in_scope: bool,
    is_pinned: bool,
}

fn any_skill_choice() -> impl Strategy<Value = SkillChoice> {
    (any::<bool>(), any::<bool>(), any::<bool>()).prop_map(
        |(is_automatic, is_in_scope, is_pinned)| SkillChoice {
            is_automatic,
            is_in_scope,
            is_pinned,
        },
    )
}

fn build_skill(index: usize, choice: &SkillChoice) -> Skill {
    let projects = if choice.is_in_scope {
        ProjectScope::AllProjects
    } else {
        ProjectScope::OnlyProjects {
            projects: vec![ProjectId(Uuid::from_u128(OTHER_PROJECT_NUMBER))],
        }
    };
    let usage = if choice.is_automatic {
        SkillUsage::Automatic
    } else {
        SkillUsage::WhenChosen
    };
    Skill {
        id: skill_id(index),
        name: format!("skill-{index}"),
        summary: String::new(),
        instructions: format!("Follow skill {index}."),
        scope: Scope {
            workspaces: WorkspaceScope::AllWorkspaces,
            projects,
        },
        usage,
        source: SkillSource::Created,
        improvement: SkillImprovement::Never,
        history: Vec::new(),
    }
}

fn skill_id(index: usize) -> SkillId {
    SkillId(Uuid::from_u128(u128::try_from(index).unwrap_or_default()))
}

fn step_pinning(
    pinned_skills: Vec<SkillId>,
    uses_automatic: bool,
) -> StepPlan {
    StepPlan {
        name: "build".to_string(),
        agent: AgentKind::ClaudeCode,
        instruction: "Build it".to_string(),
        pinned_skills,
        uses_automatic_skills: uses_automatic,
        approval_policy: ApprovalPolicy::NeverAsk,
        upstream_step_names: Vec::new(),
        outcome_choices: Vec::new(),
        loop_round_limit: None,
    }
}

proptest! {
    #[test]
    fn test_select_step_skills_property_offers_pinned_and_fitting_skills(
        choices in vec(any_skill_choice(), 0..8),
        uses_automatic in any::<bool>(),
    ) {
        let skills: Vec<Skill> = choices
            .iter()
            .enumerate()
            .map(|(index, choice)| build_skill(index, choice))
            .collect();
        let pinned: Vec<SkillId> = choices
            .iter()
            .enumerate()
            .filter(|(_index, choice)| choice.is_pinned)
            .map(|(index, _choice)| skill_id(index))
            .collect();
        let step = step_pinning(pinned, uses_automatic);

        let selected = select_step_skills(
            &step,
            &skills,
            WorkspaceId(Uuid::from_u128(WORKSPACE_NUMBER)),
            ProjectId(Uuid::from_u128(PROJECT_NUMBER)),
        );

        let selected_ids: Vec<SkillId> =
            selected.iter().map(|skill| skill.id).collect();
        let mut previous_position = None;
        for (index, choice) in choices.iter().enumerate() {
            let position =
                selected_ids.iter().position(|id| *id == skill_id(index));
            let is_offered = uses_automatic
                && choice.is_automatic
                && choice.is_in_scope;
            prop_assert_eq!(
                position.is_some(),
                choice.is_pinned || is_offered
            );
            if position.is_some() {
                prop_assert!(position > previous_position);
                previous_position = position;
            }
        }
    }
}
