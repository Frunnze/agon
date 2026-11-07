use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{StepKind, Workflow, WorkflowAgent};
use orchestration_core::workflow_document::render_workflow_document;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::document_reading::{
    count_changed_lines, document_workflow, find_block, list_step_blocks,
    lists_in_order,
};
use crate::entity_strategies::runner_target;
use crate::workflow_strategies::workflow_from_parts;

const AVAILABILITY_LINE: usize = 1;
const AVAILABILITY_KEY: &str = "available_in";
const ALL_WORKSPACES_LINE: &str = "available_in: all_workspaces";
const ANY_FREE_RUNNER_LINE: &str = "    runs_on: any free runner";
const LARGEST_WORKSPACE_COUNT: usize = 4;

fn workspace_scope() -> impl Strategy<Value = WorkspaceScope> {
    prop_oneof![
        Just(WorkspaceScope::AllWorkspaces),
        vec(any::<u128>(), 0..=LARGEST_WORKSPACE_COUNT).prop_map(|numbers| {
            let workspaces = numbers
                .into_iter()
                .map(|number| WorkspaceId(Uuid::from_u128(number)))
                .collect();
            WorkspaceScope::OnlyWorkspaces { workspaces }
        }),
    ]
}

fn hostile_runner_target() -> impl Strategy<Value = RunnerTarget> {
    prop_oneof![
        runner_target(),
        Just(RunnerTarget::SpecificRunner {
            device_id: DeviceId("any free runner".to_owned()),
        }),
        Just(RunnerTarget::RunnerWithLabels { labels: Vec::new() }),
        ".{0,6}".prop_map(|device_id| RunnerTarget::SpecificRunner {
            device_id: DeviceId(device_id),
        }),
        vec(".{0,4}", 0..3)
            .prop_map(|labels| RunnerTarget::RunnerWithLabels { labels }),
    ]
}

fn with_availability(
    workflow: &Workflow,
    availability: WorkspaceScope,
) -> Workflow {
    Workflow {
        availability,
        ..workflow.clone()
    }
}

fn with_runner(
    workflow: &Workflow,
    position: usize,
    runs_on: RunnerTarget,
) -> Workflow {
    let mut agents = workflow.agents.clone();
    agents[position] = WorkflowAgent {
        runs_on,
        step_kind: StepKind::Agent,
        ..agents[position].clone()
    };
    workflow_from_parts(agents, workflow.connections.clone())
}

fn drop_availability(document: &str) -> Vec<&str> {
    document
        .lines()
        .filter(|line| !line.starts_with(AVAILABILITY_KEY))
        .collect()
}

fn find_runner_key(target: &RunnerTarget) -> &'static str {
    match target {
        RunnerTarget::RunnerWithLabels { .. } => "    requires: [",
        RunnerTarget::AnyFreeRunner | RunnerTarget::SpecificRunner { .. } => {
            "    runs_on: "
        }
    }
}

fn read_runner_line(workflow: &Workflow, position: usize) -> String {
    let document = render_workflow_document(workflow);
    let blocks = list_step_blocks(&document);
    let name = &workflow.agents[position].name;
    let block = find_block(&blocks, name).unwrap_or_default();
    block
        .get(1)
        .map(|line| (*line).to_owned())
        .unwrap_or_default()
}

proptest! {
    #[test]
    fn test_render_availability_property_all_workspaces_has_its_own_word(
        workflow in document_workflow(),
        availability in workspace_scope(),
    ) {
        let changed = with_availability(&workflow, availability.clone());
        let document = render_workflow_document(&changed);

        let line = document.lines().nth(AVAILABILITY_LINE).unwrap_or_default();
        let is_all = availability == WorkspaceScope::AllWorkspaces;
        prop_assert_eq!(line == ALL_WORKSPACES_LINE, is_all);
    }

    #[test]
    fn test_render_availability_property_lists_each_workspace_in_order(
        workflow in document_workflow(),
        numbers in vec(any::<u128>(), 0..=LARGEST_WORKSPACE_COUNT),
    ) {
        let workspaces: Vec<WorkspaceId> = numbers
            .into_iter()
            .map(|number| WorkspaceId(Uuid::from_u128(number)))
            .collect();
        let availability = WorkspaceScope::OnlyWorkspaces {
            workspaces: workspaces.clone(),
        };

        let changed = with_availability(&workflow, availability);
        let document = render_workflow_document(&changed);

        let line = document.lines().nth(AVAILABILITY_LINE).unwrap_or_default();
        let workspace_texts: Vec<String> = workspaces
            .iter()
            .map(|workspace| workspace.0.to_string())
            .collect();
        let separator_count = line.matches(", ").count();
        prop_assert!(line.starts_with("available_in: ["), "{line}");
        prop_assert!(line.ends_with(']'), "{line}");
        prop_assert!(lists_in_order(line, &workspace_texts), "{line}");
        prop_assert_eq!(separator_count, workspaces.len().saturating_sub(1));
    }

    #[test]
    fn test_render_availability_property_changes_only_its_own_line(
        workflow in document_workflow(),
        first in workspace_scope(),
        second in workspace_scope(),
    ) {
        let first_workflow = with_availability(&workflow, first.clone());
        let second_workflow = with_availability(&workflow, second.clone());
        let first_document = render_workflow_document(&first_workflow);
        let second_document = render_workflow_document(&second_workflow);

        let expected_changes = usize::from(first != second);
        let changed_lines =
            count_changed_lines(&first_document, &second_document);
        prop_assert_eq!(changed_lines, expected_changes);
        prop_assert_eq!(
            drop_availability(&first_document),
            drop_availability(&second_document)
        );
    }

    #[test]
    fn test_render_runner_target_property_any_free_runner_reads_plainly(
        workflow in document_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let position = pick.index(workflow.agents.len());
        let target = RunnerTarget::AnyFreeRunner;
        let changed = with_runner(&workflow, position, target);

        let line = read_runner_line(&changed, position);
        prop_assert_eq!(line, ANY_FREE_RUNNER_LINE);
    }

    #[test]
    fn test_render_runner_target_property_different_targets_read_apart(
        workflow in document_workflow(),
        pick in any::<prop::sample::Index>(),
        first in hostile_runner_target(),
        second in hostile_runner_target(),
    ) {
        let position = pick.index(workflow.agents.len());
        let first_workflow = with_runner(&workflow, position, first.clone());
        let second_workflow = with_runner(&workflow, position, second.clone());
        let first_line = read_runner_line(&first_workflow, position);
        let second_line = read_runner_line(&second_workflow, position);

        prop_assert_eq!(first_line == second_line, first == second);
    }

    #[test]
    fn test_render_runner_target_property_names_its_key_by_target_kind(
        workflow in document_workflow(),
        pick in any::<prop::sample::Index>(),
        target in hostile_runner_target(),
    ) {
        let position = pick.index(workflow.agents.len());
        let changed = with_runner(&workflow, position, target.clone());
        let line = read_runner_line(&changed, position);

        let expected_prefix = find_runner_key(&target);
        prop_assert!(line.starts_with(expected_prefix), "{line}");
        prop_assert_eq!(line.lines().count(), 1);
    }
}
