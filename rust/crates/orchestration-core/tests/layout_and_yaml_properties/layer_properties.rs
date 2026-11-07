use orchestration_core::workflow::{AgentConnection, Workflow};
use orchestration_core::workflow_graph::forward_connections;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::dag_strategies::{forked_dag_workflow, shuffle_storage};
use crate::layer_model::{
    expect_rows, find_vertical, list_agent_ids, list_positions,
    list_verticals, row_vertical,
};
use crate::layout_reading::{hostile_workflow, is_same_coordinate};
use crate::routing_fixtures::{connect, routing_workflow};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const MISSING_STEP_BASE: u128 = 1_000;
const LARGEST_EXTRA_CONNECTIONS: usize = 6;
const LARGEST_STEP_NUMBER: u128 = 16;
const LARGEST_CHAIN_LENGTH: u128 = 30;
const TOGGLED_OUTCOME_PREFIX: &str = "toggled";
const LOOP_ROUND_LIMIT: u32 = 3;

type ExtraPick = (u128, u128, bool);

fn with_extra_connections(
    workflow: &Workflow,
    extra_connections: Vec<AgentConnection>,
) -> Workflow {
    let mut connections = workflow.connections.clone();
    connections.extend(extra_connections);
    workflow_from_parts(workflow.agents.clone(), connections)
}

fn dangling_connections(picks: &[ExtraPick]) -> Vec<AgentConnection> {
    let mut connections = Vec::new();
    for (index, (known, missing, is_outgoing)) in picks.iter().enumerate() {
        let missing_number = MISSING_STEP_BASE + missing;
        let condition = format!("{TOGGLED_OUTCOME_PREFIX} {index}");
        let (from, to) = if *is_outgoing {
            (*known, missing_number)
        } else {
            (missing_number, *known)
        };
        connections.push(connect(from, to, Some(&condition), None));
    }
    connections
}

fn loop_connections(picks: &[ExtraPick]) -> Vec<AgentConnection> {
    let mut connections = Vec::new();
    for (from, to, is_conditioned) in picks {
        let condition = is_conditioned.then_some(TOGGLED_OUTCOME_PREFIX);
        connections.push(connect(
            *from,
            *to,
            condition,
            Some(LOOP_ROUND_LIMIT),
        ));
    }
    connections
}

fn toggle_conditions(workflow: &Workflow) -> Workflow {
    let mut connections = Vec::new();
    for (index, connection) in workflow.connections.iter().enumerate() {
        let condition = match connection.condition {
            Some(_) => None,
            None => Some(format!("{TOGGLED_OUTCOME_PREFIX} {index}")),
        };
        connections.push(AgentConnection {
            condition,
            ..connection.clone()
        });
    }
    workflow_from_parts(workflow.agents.clone(), connections)
}

fn extra_picks() -> impl Strategy<Value = Vec<ExtraPick>> {
    let pick = (
        0..LARGEST_STEP_NUMBER,
        0..LARGEST_STEP_NUMBER,
        any::<bool>(),
    );
    vec(pick, 1..=LARGEST_EXTRA_CONNECTIONS)
}

fn reversed_chain(length: u128) -> Workflow {
    let mut chain = routing_workflow(length, Vec::new());
    for step in (1..length).rev() {
        chain.connections.push(connect(step - 1, step, None, None));
    }
    chain.agents.reverse();
    chain
}

fn has_forward_input(workflow: &Workflow, agent_index: usize) -> bool {
    let agent_id = workflow.agents[agent_index].id;
    let known_ids = list_agent_ids(workflow);
    forward_connections(workflow).iter().any(|connection| {
        connection.to == agent_id && known_ids.contains(&connection.from)
    })
}

proptest! {
    #[test]
    fn test_list_forward_links_property_missing_steps_change_nothing(
        workflow in forked_dag_workflow(),
        picks in extra_picks(),
    ) {
        let dangling = with_extra_connections(
            &workflow,
            dangling_connections(&picks),
        );

        let expected = list_positions(&lay_out_workflow(&workflow));
        let laid_out = list_positions(&lay_out_workflow(&dangling));

        prop_assert_eq!(laid_out, expected);
    }

    #[test]
    fn test_list_forward_links_property_loops_change_no_position(
        workflow in forked_dag_workflow(),
        picks in extra_picks(),
    ) {
        let looped =
            with_extra_connections(&workflow, loop_connections(&picks));

        let expected = list_positions(&lay_out_workflow(&workflow));
        let laid_out = list_positions(&lay_out_workflow(&looped));

        prop_assert_eq!(laid_out, expected);
    }

    #[test]
    fn test_list_forward_links_property_conditions_never_change_rows(
        workflow in forked_dag_workflow(),
    ) {
        let toggled = toggle_conditions(&workflow);

        let expected = list_verticals(&lay_out_workflow(&workflow));
        let laid_out = list_verticals(&lay_out_workflow(&toggled));

        prop_assert_eq!(laid_out, expected);
    }

    #[test]
    fn test_assign_layers_property_rows_match_the_longest_input_path(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let expected_rows = expect_rows(&workflow);

        for agent in &laid_out.agents {
            let expected_vertical = row_vertical(expected_rows[&agent.id]);
            let vertical = agent.position.vertical;
            prop_assert!(
                is_same_coordinate(vertical, expected_vertical),
                "{} instead of {}",
                vertical,
                expected_vertical
            );
        }
    }

    #[test]
    fn test_assign_layers_property_a_reversed_chain_fills_every_row(
        length in 1..=LARGEST_CHAIN_LENGTH,
    ) {
        let laid_out = lay_out_workflow(&reversed_chain(length));

        for step in 0..length {
            let vertical = find_vertical(&laid_out, agent_identifier(step));
            let row = usize::try_from(step).unwrap_or(usize::MAX);
            prop_assert_eq!(vertical, Some(row_vertical(row)));
        }
    }

    #[test]
    fn test_assign_layers_property_steps_without_inputs_sit_on_top(
        workflow in hostile_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for agent_index in 0..workflow.agents.len() {
            if !has_forward_input(&workflow, agent_index) {
                let vertical = laid_out.agents[agent_index].position.vertical;
                prop_assert!(is_same_coordinate(vertical, row_vertical(0)));
            }
        }
    }

    #[test]
    fn test_goes_down_property_every_forward_connection_points_down(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for connection in forward_connections(&laid_out) {
            let upstream = find_vertical(&laid_out, connection.from);
            let downstream = find_vertical(&laid_out, connection.to);
            prop_assert!(upstream < downstream, "{:?}", connection);
        }
    }

    #[test]
    fn test_goes_down_property_hostile_workflows_never_stack_steps(
        workflow in hostile_workflow().prop_flat_map(shuffle_storage),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let positions = list_positions(&laid_out);
        for (index, position) in positions.iter().enumerate() {
            prop_assert!(position.horizontal.is_finite());
            prop_assert!(position.vertical >= 0.0);
            for other in &positions[index + 1..] {
                prop_assert!(position != other, "{:?}", position);
            }
        }
    }

    #[test]
    fn test_goes_down_property_hostile_layout_is_idempotent(
        workflow in hostile_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let laid_out_again = lay_out_workflow(&laid_out);

        prop_assert_eq!(laid_out_again, laid_out);
    }
}
