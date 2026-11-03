use std::collections::BTreeSet;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{CanvasPosition, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::{
    find_agent_by_id, forward_connections,
};
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::branching_strategies::{
    branching_plan_with_agent_counts, build_branching_workflow,
};
use crate::workflow_strategies::arbitrary_workflow;

const DRAWN_STEP_WIDTH: f64 = 160.0;
const DRAWN_STEP_HEIGHT: f64 = 88.0;
const ROW_PITCH: f64 = 152.0;
const TOP_ROW_VERTICAL: f64 = 0.0;
const SMALLEST_DRAFTED_STEP_COUNT: usize = 1;
const LARGEST_DRAFTED_STEP_COUNT: usize = 10;

fn valid_drafted_workflow() -> impl Strategy<Value = Workflow> {
    branching_plan_with_agent_counts(
        SMALLEST_DRAFTED_STEP_COUNT..=LARGEST_DRAFTED_STEP_COUNT,
    )
    .prop_map(|plan| build_branching_workflow(&plan))
}

fn is_same_coordinate(first: f64, second: f64) -> bool {
    first.total_cmp(&second).is_eq()
}

fn do_steps_overlap(first: CanvasPosition, second: CanvasPosition) -> bool {
    let horizontal_distance = (first.horizontal - second.horizontal).abs();
    let vertical_distance = (first.vertical - second.vertical).abs();
    horizontal_distance < DRAWN_STEP_WIDTH
        && vertical_distance < DRAWN_STEP_HEIGHT
}

fn count_overlapping_pairs(workflow: &Workflow) -> usize {
    let agents = &workflow.agents;
    let mut overlapping_pairs = 0;
    for i in 0..agents.len() {
        for j in (i + 1)..agents.len() {
            if do_steps_overlap(agents[i].position, agents[j].position) {
                overlapping_pairs += 1;
            }
        }
    }
    overlapping_pairs
}

fn list_distinct_inputs<'workflow>(
    workflow: &'workflow Workflow,
    agent: &WorkflowAgent,
) -> Vec<&'workflow WorkflowAgent> {
    let mut input_ids: BTreeSet<WorkflowAgentId> = BTreeSet::new();
    for connection in forward_connections(workflow) {
        if connection.to == agent.id {
            input_ids.insert(connection.from);
        }
    }

    let mut inputs = Vec::new();
    for input_id in input_ids {
        if let Some(input) = find_agent_by_id(workflow, input_id) {
            inputs.push(input);
        }
    }
    inputs
}

fn find_expected_vertical(workflow: &Workflow, agent: &WorkflowAgent) -> f64 {
    let mut expected_vertical = TOP_ROW_VERTICAL;
    for input in list_distinct_inputs(workflow, agent) {
        let below_input = input.position.vertical + ROW_PITCH;
        expected_vertical = expected_vertical.max(below_input);
    }
    expected_vertical
}

fn find_average_input_horizontal_above(
    workflow: &Workflow,
    agent: &WorkflowAgent,
) -> f64 {
    let row_above = agent.position.vertical - ROW_PITCH;
    let mut horizontal_total = 0.0;
    let mut input_count = 0.0;
    for input in list_distinct_inputs(workflow, agent) {
        if is_same_coordinate(input.position.vertical, row_above) {
            horizontal_total += input.position.horizontal;
            input_count += 1.0;
        }
    }

    if input_count == 0.0 {
        return 0.0;
    }
    horizontal_total / input_count
}

fn scatter_positions(workflow: &Workflow, spacing: f64) -> Workflow {
    let mut agents = Vec::new();
    let mut horizontal = spacing;
    for agent in &workflow.agents {
        let position = CanvasPosition {
            horizontal,
            vertical: spacing - horizontal,
        };
        agents.push(WorkflowAgent {
            position,
            ..agent.clone()
        });
        horizontal += spacing;
    }
    Workflow {
        agents,
        ..workflow.clone()
    }
}

fn restore_drafted_positions(
    laid_out: &Workflow,
    drafted: &Workflow,
) -> Workflow {
    let mut agents = Vec::new();
    for (placed, drafted_agent) in laid_out.agents.iter().zip(&drafted.agents)
    {
        agents.push(WorkflowAgent {
            position: drafted_agent.position,
            ..placed.clone()
        });
    }
    Workflow {
        agents,
        ..laid_out.clone()
    }
}

proptest! {
    #[test]
    fn test_lay_out_workflow_property_no_two_steps_overlap(
        workflow in valid_drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        prop_assert_eq!(count_overlapping_pairs(&laid_out), 0);
    }

    #[test]
    fn test_lay_out_workflow_property_never_stacks_steps_of_any_workflow(
        workflow in arbitrary_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        prop_assert_eq!(count_overlapping_pairs(&laid_out), 0);
        prop_assert_eq!(laid_out.agents.len(), workflow.agents.len());
    }

    #[test]
    fn test_lay_out_workflow_property_forward_connections_point_down(
        workflow in valid_drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for connection in forward_connections(&laid_out) {
            let source = find_agent_by_id(&laid_out, connection.from);
            let target = find_agent_by_id(&laid_out, connection.to);
            let (Some(source), Some(target)) = (source, target) else {
                prop_assert!(false, "a connection end is missing");
                return Ok(());
            };
            let source_bottom = source.position.vertical + DRAWN_STEP_HEIGHT;
            prop_assert!(target.position.vertical > source_bottom);
        }
    }

    #[test]
    fn test_lay_out_workflow_property_each_step_sits_below_deepest_input(
        workflow in valid_drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for agent in &laid_out.agents {
            let expected_vertical = find_expected_vertical(&laid_out, agent);
            let vertical = agent.position.vertical;
            prop_assert!(is_same_coordinate(vertical, expected_vertical));
        }
    }

    #[test]
    fn test_lay_out_workflow_property_rows_follow_inputs_then_drafted_order(
        workflow in valid_drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let agents = &laid_out.agents;
        for i in 0..agents.len() {
            for j in (i + 1)..agents.len() {
                let earlier = &agents[i];
                let later = &agents[j];
                let vertical = earlier.position.vertical;
                if !is_same_coordinate(vertical, later.position.vertical) {
                    continue;
                }
                let earlier_average =
                    find_average_input_horizontal_above(&laid_out, earlier);
                let later_average =
                    find_average_input_horizontal_above(&laid_out, later);
                let is_earlier_left = earlier.position.horizontal
                    < later.position.horizontal;
                let should_earlier_be_left = earlier_average <= later_average;
                prop_assert_eq!(is_earlier_left, should_earlier_be_left);
            }
        }
    }

    #[test]
    fn test_lay_out_workflow_property_is_deterministic(
        workflow in valid_drafted_workflow(),
    ) {
        let first_layout = lay_out_workflow(&workflow);
        let second_layout = lay_out_workflow(&workflow);

        prop_assert_eq!(first_layout, second_layout);
    }

    #[test]
    fn test_lay_out_workflow_property_ignores_the_drafted_positions(
        workflow in valid_drafted_workflow(),
        spacing in 1.0..500.0_f64,
    ) {
        let scattered = scatter_positions(&workflow, spacing);

        let from_drafted = lay_out_workflow(&workflow);
        let from_scattered = lay_out_workflow(&scattered);

        prop_assert_eq!(from_drafted, from_scattered);
    }

    #[test]
    fn test_lay_out_workflow_property_is_idempotent_on_its_output(
        workflow in valid_drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let laid_out_again = lay_out_workflow(&laid_out);

        prop_assert_eq!(laid_out_again, laid_out);
    }

    #[test]
    fn test_lay_out_workflow_property_positions_are_non_negative(
        workflow in arbitrary_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for agent in &laid_out.agents {
            prop_assert!(agent.position.horizontal >= 0.0);
            prop_assert!(agent.position.vertical >= 0.0);
        }
    }

    #[test]
    fn test_lay_out_workflow_property_changes_nothing_but_positions(
        workflow in arbitrary_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let restored = restore_drafted_positions(&laid_out, &workflow);
        prop_assert_eq!(restored, workflow);
    }
}
