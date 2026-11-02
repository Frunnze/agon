use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    WorkflowAgentId, WorkflowId, WorkspaceId,
};
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{
    AgentKind, CanvasPosition, Workflow, WorkflowAgent,
};
use orchestration_node::item_drafting::check_new_workflow_draft;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

const CHECK_CASES: u32 = 64;
const MAXIMUM_TAKEN_NAMES: usize = 4;
const MAXIMUM_LISTED_WORKSPACES: usize = 3;
const THIS_WORKSPACE_NUMBER: u128 = 1;
const DISTINCT_WORKSPACE_COUNT: u128 = 3;

fn this_workspace() -> WorkspaceId {
    WorkspaceId(Uuid::from_u128(THIS_WORKSPACE_NUMBER))
}

fn availability_strategy() -> impl Strategy<Value = WorkspaceScope> {
    let workspace = (0..DISTINCT_WORKSPACE_COUNT)
        .prop_map(|number| WorkspaceId(Uuid::from_u128(number)));
    prop_oneof![
        Just(WorkspaceScope::AllWorkspaces),
        vec(workspace, 0..MAXIMUM_LISTED_WORKSPACES).prop_map(|workspaces| {
            WorkspaceScope::OnlyWorkspaces { workspaces }
        }),
    ]
}

fn drafted_workflow(name: String, availability: WorkspaceScope) -> Workflow {
    Workflow {
        id: WorkflowId(Uuid::nil()),
        name,
        availability,
        agents: vec![WorkflowAgent {
            id: WorkflowAgentId(Uuid::nil()),
            name: "plan".to_owned(),
            kind: Some(AgentKind::ClaudeCode),
            task: "Plan the feature".to_owned(),
            runs_on: RunnerTarget::AnyFreeRunner,
            skills: Vec::new(),
            uses_automatic_skills: false,
            approval_policy: ApprovalPolicy::NeverAsk,
            position: CanvasPosition {
                horizontal: 0.0,
                vertical: 0.0,
            },
        }],
        connections: Vec::new(),
        signature: None,
    }
}

fn is_offered_here(availability: &WorkspaceScope) -> bool {
    match availability {
        WorkspaceScope::AllWorkspaces => true,
        WorkspaceScope::OnlyWorkspaces { workspaces } => {
            workspaces.as_slice() == [this_workspace()]
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_check_new_workflow_draft_property_needs_free_name_offered_here(
        name in "[a-z0-9-]{1,12}|[A-Z ]{1,6}",
        taken_names in vec("[a-z0-9-]{1,12}", 0..MAXIMUM_TAKEN_NAMES),
        availability in availability_strategy(),
    ) {
        let is_well_formed = name.chars().all(|character| {
            character.is_ascii_lowercase()
                || character.is_ascii_digit()
                || character == '-'
        });
        let is_free = !taken_names.contains(&name);
        let is_offered = is_offered_here(&availability);
        let drafted = drafted_workflow(name, availability);

        let checked =
            check_new_workflow_draft(&drafted, this_workspace(), &taken_names);

        let is_accepted = is_well_formed && is_free && is_offered;
        prop_assert_eq!(checked.is_ok(), is_accepted, "{:?}", checked);
    }
}
