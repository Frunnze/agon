use orchestration_core::workflow::{AgentConnection, StepKind, Workflow};
use orchestration_core::workflow_graph::forward_connections;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::layout_reading::{
    ONE_COLUMN, drafted_workflow, drafted_workflow_without_forks,
    find_row_index, find_widest_row_size, is_same_coordinate, list_rows,
    measure_count, read_column,
};
use crate::routing_fixtures::routing_agent;
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const LEFT_EDGE: f64 = 0.0;
const ONE_BRANCH_OUTCOME: &str = "only way";
const OTHER_BRANCH_OUTCOME: &str = "other way";
const TOP_ROW: usize = 0;
const SIDES_OF_A_ROW: f64 = 2.0;

fn count_agents(workflow: &Workflow) -> u128 {
    let mut agent_count = 0;
    for _ in &workflow.agents {
        agent_count += 1;
    }
    agent_count
}

fn add_isolated_step(workflow: &Workflow) -> Workflow {
    let mut agents = workflow.agents.clone();
    agents.push(routing_agent(count_agents(workflow), StepKind::Agent));
    workflow_from_parts(agents, workflow.connections.clone())
}

fn has_forward_input(workflow: &Workflow, position: usize) -> bool {
    let agent_id = workflow.agents[position].id;
    forward_connections(workflow)
        .iter()
        .any(|connection| connection.to == agent_id)
}

fn hang_under_one_branch(
    body: &Workflow,
    branch_outcomes: &[Option<&str>],
) -> Workflow {
    let root_number = count_agents(body);
    let head_number = root_number + 1;
    let mut agents = body.agents.clone();
    agents.push(routing_agent(root_number, StepKind::Agent));
    agents.push(routing_agent(head_number, StepKind::Agent));

    let mut connections = body.connections.clone();
    for outcome in branch_outcomes {
        connections.push(AgentConnection {
            condition: outcome.map(str::to_owned),
            ..AgentConnection::plain(
                agent_identifier(root_number),
                agent_identifier(head_number),
            )
        });
    }
    for position in 0..body.agents.len() {
        if !has_forward_input(body, position) {
            connections.push(AgentConnection::plain(
                agent_identifier(head_number),
                body.agents[position].id,
            ));
        }
    }
    workflow_from_parts(agents, connections)
}

proptest! {
    #[test]
    fn test_measure_widest_row_property_a_widest_row_starts_at_the_left(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let rows = list_rows(&laid_out);
        let widest_row_size = find_widest_row_size(&rows);
        let widest_rows_start_left = rows
            .iter()
            .filter(|row| row.len() == widest_row_size)
            .all(|row| {
                row.first().is_some_and(|leftmost| {
                    is_same_coordinate(read_column(leftmost), LEFT_EDGE)
                })
            });
        prop_assert!(widest_rows_start_left);
    }

    #[test]
    fn test_measure_widest_row_property_the_canvas_ends_after_the_widest(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let rows = list_rows(&laid_out);
        let mut rightmost_edge = LEFT_EDGE;
        for agent in &laid_out.agents {
            let right_edge = read_column(agent) + ONE_COLUMN;
            rightmost_edge = rightmost_edge.max(right_edge);
        }
        let widest_row_width = measure_count(find_widest_row_size(&rows));
        prop_assert!(is_same_coordinate(rightmost_edge, widest_row_width));
    }

    #[test]
    fn test_measure_widest_row_property_a_new_top_step_shifts_lower_rows(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let rows = list_rows(&laid_out);
        let top_row_size = rows.first().map_or(0, Vec::len);
        let widest_row_size = find_widest_row_size(&rows);
        let widened_size = widest_row_size.max(top_row_size + 1);
        let expected_shift = (measure_count(widened_size)
            - measure_count(widest_row_size))
            / SIDES_OF_A_ROW;

        let widened = lay_out_workflow(&add_isolated_step(&workflow));

        let agent_pairs = laid_out.agents.iter().zip(&widened.agents);
        for (agent, widened_agent) in agent_pairs {
            if find_row_index(&rows, agent.id) == Some(TOP_ROW) {
                continue;
            }
            let shift = read_column(widened_agent) - read_column(agent);
            prop_assert!(is_same_coordinate(shift, expected_shift));
        }
    }

    #[test]
    fn test_measure_item_width_property_one_branch_lays_out_like_a_line(
        body in drafted_workflow_without_forks(),
    ) {
        let forked = hang_under_one_branch(&body, &[Some(ONE_BRANCH_OUTCOME)]);
        let plain = hang_under_one_branch(&body, &[None]);

        let forked_layout = lay_out_workflow(&forked);
        let plain_layout = lay_out_workflow(&plain);

        for (forked_agent, plain_agent) in
            forked_layout.agents.iter().zip(&plain_layout.agents)
        {
            prop_assert_eq!(forked_agent.position, plain_agent.position);
        }
    }

    #[test]
    fn test_measure_item_width_property_a_repeated_branch_is_one_lane(
        body in drafted_workflow_without_forks(),
    ) {
        let once = hang_under_one_branch(&body, &[Some(ONE_BRANCH_OUTCOME)]);
        let twice = hang_under_one_branch(
            &body,
            &[Some(ONE_BRANCH_OUTCOME), Some(OTHER_BRANCH_OUTCOME)],
        );

        let once_layout = lay_out_workflow(&once);
        let twice_layout = lay_out_workflow(&twice);

        for (once_agent, twice_agent) in
            once_layout.agents.iter().zip(&twice_layout.agents)
        {
            prop_assert_eq!(once_agent.position, twice_agent.position);
        }
    }

    #[test]
    fn test_measure_widths_property_rows_never_reach_past_the_canvas(
        workflow in drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let rows = list_rows(&laid_out);

        let mut leftmost_edge = f64::INFINITY;
        let mut rightmost_edge = LEFT_EDGE;
        for agent in &laid_out.agents {
            leftmost_edge = leftmost_edge.min(read_column(agent));
            let right_edge = read_column(agent) + ONE_COLUMN;
            rightmost_edge = rightmost_edge.max(right_edge);
        }
        let used_width = rightmost_edge - leftmost_edge;
        let widest_row_width = measure_count(find_widest_row_size(&rows));
        let agent_count = measure_count(laid_out.agents.len());
        prop_assert!(used_width >= widest_row_width, "{used_width}");
        prop_assert!(rightmost_edge <= agent_count, "{rightmost_edge}");
    }
}
