use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, Workflow, WorkflowAgent};
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fork_reading::read_column_of;
use crate::layout_reading::{
    drafted_workflow, drafted_workflow_without_forks, find_row_index,
    is_same_coordinate, list_rows, measure_count, read_column,
};
use crate::routing_fixtures::{connect, routing_workflow};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const LEFT_OUTCOME: &str = "left";
const RIGHT_OUTCOME: &str = "right";
const SMALLEST_SIBLING_COUNT: u128 = 2;
const LARGEST_SIBLING_COUNT: u128 = 6;
const SMALLEST_TOP_ROW_SIZE: u128 = 2;
const LARGEST_TOP_ROW_SIZE: u128 = 6;
const RENAMED_ID_OFFSET: u128 = 1_000;
const ROWS_BETWEEN_FAR_STEPS: usize = 2;

fn shuffled(workflow: Workflow) -> impl Strategy<Value = Workflow> {
    let connections = workflow.connections.clone();
    Just(workflow.agents)
        .prop_shuffle()
        .prop_map(move |agents| {
            workflow_from_parts(agents, connections.clone())
        })
}

fn two_forks() -> Workflow {
    routing_workflow(
        6,
        vec![
            connect(0, 2, Some(LEFT_OUTCOME), None),
            connect(0, 3, Some(RIGHT_OUTCOME), None),
            connect(1, 4, Some(LEFT_OUTCOME), None),
            connect(1, 5, Some(RIGHT_OUTCOME), None),
        ],
    )
}

fn step_beside_fork() -> Workflow {
    routing_workflow(
        5,
        vec![
            connect(0, 2, None, None),
            connect(1, 3, Some(LEFT_OUTCOME), None),
            connect(1, 4, Some(RIGHT_OUTCOME), None),
        ],
    )
}

fn siblings(child_count: u128) -> Workflow {
    let mut connections = Vec::new();
    for child in 1..=child_count {
        connections.push(connect(0, child, None, None));
    }
    routing_workflow(child_count + 1, connections)
}

fn fed_from_both_ends(top_row_size: u128) -> Workflow {
    let last = top_row_size - 1;
    let (middle, left_child, right_child) =
        (top_row_size, top_row_size + 1, top_row_size + 2);
    routing_workflow(
        top_row_size + 3,
        vec![
            connect(0, middle, None, None),
            connect(last, middle, None, None),
            connect(0, left_child, None, None),
            connect(last, right_child, None, None),
        ],
    )
}

fn shuffle_the_children(
    top_row_size: u128,
) -> impl Strategy<Value = Workflow> {
    let workflow = fed_from_both_ends(top_row_size);
    let split = workflow.agents.len() - 3;
    let top_agents = workflow.agents[..split].to_vec();
    let children = workflow.agents[split..].to_vec();
    let connections = workflow.connections;
    Just(children)
        .prop_shuffle()
        .prop_map(move |shuffled_children| {
            let mut agents = top_agents.clone();
            agents.extend(shuffled_children);
            workflow_from_parts(agents, connections.clone())
        })
}

fn rename_id(agent_id: WorkflowAgentId) -> WorkflowAgentId {
    WorkflowAgentId(Uuid::from_u128(agent_id.0.as_u128() + RENAMED_ID_OFFSET))
}

fn rename_everything(workflow: &Workflow) -> Workflow {
    let mut agents = Vec::new();
    for agent in &workflow.agents {
        agents.push(WorkflowAgent {
            id: rename_id(agent.id),
            name: format!("renamed {}", agent.name),
            ..agent.clone()
        });
    }
    let mut connections = Vec::new();
    for connection in &workflow.connections {
        connections.push(AgentConnection {
            from: rename_id(connection.from),
            to: rename_id(connection.to),
            ..connection.clone()
        });
    }
    workflow_from_parts(agents, connections)
}

fn add_far_connection(
    workflow: &Workflow,
    pick: prop::sample::Index,
) -> Option<Workflow> {
    let laid_out = lay_out_workflow(workflow);
    let rows = list_rows(&laid_out);
    let mut far_pairs = Vec::new();
    for upstream in &laid_out.agents {
        for downstream in &laid_out.agents {
            let upstream_row = find_row_index(&rows, upstream.id)?;
            let downstream_row = find_row_index(&rows, downstream.id)?;
            if downstream_row >= upstream_row + ROWS_BETWEEN_FAR_STEPS {
                far_pairs.push((upstream.id, downstream.id));
            }
        }
    }
    if far_pairs.is_empty() {
        return None;
    }
    let (from, to) = far_pairs[pick.index(far_pairs.len())];
    let mut connections = workflow.connections.clone();
    connections.push(AgentConnection::plain(from, to));
    Some(workflow_from_parts(workflow.agents.clone(), connections))
}

fn column_of(workflow: &Workflow, number: u128) -> f64 {
    read_column_of(workflow, agent_identifier(number)).unwrap_or(f64::NAN)
}

proptest! {
    #[test]
    fn test_find_upstream_column_property_fork_groups_follow_their_forks(
        workflow in shuffled(two_forks()),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let is_first_fork_left =
            column_of(&laid_out, 0) < column_of(&laid_out, 1);
        let first_heads = [column_of(&laid_out, 2), column_of(&laid_out, 3)];
        let second_heads = [column_of(&laid_out, 4), column_of(&laid_out, 5)];
        for first_head in first_heads {
            for second_head in second_heads {
                prop_assert_eq!(first_head < second_head, is_first_fork_left);
            }
        }
    }

    #[test]
    fn test_find_upstream_column_property_a_step_and_a_fork_keep_sides(
        workflow in shuffled(step_beside_fork()),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let is_step_left = column_of(&laid_out, 0) < column_of(&laid_out, 1);
        let child_column = column_of(&laid_out, 2);
        for head in [3, 4] {
            let head_column = column_of(&laid_out, head);
            prop_assert_eq!(child_column < head_column, is_step_left);
        }
    }

    #[test]
    fn test_find_average_input_column_property_ignores_far_inputs(
        workflow in drafted_workflow_without_forks(),
        pick in any::<prop::sample::Index>(),
    ) {
        let Some(extended) = add_far_connection(&workflow, pick) else {
            return Ok(());
        };

        let laid_out = lay_out_workflow(&workflow);
        let extended_layout = lay_out_workflow(&extended);

        prop_assert_eq!(laid_out.agents, extended_layout.agents);
    }

    #[test]
    fn test_find_average_input_column_property_averages_both_inputs(
        (top_row_size, workflow) in
            (SMALLEST_TOP_ROW_SIZE..=LARGEST_TOP_ROW_SIZE).prop_flat_map(
                |top_row_size| {
                    (Just(top_row_size), shuffle_the_children(top_row_size))
                },
            ),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let middle = column_of(&laid_out, top_row_size);
        let left_child = column_of(&laid_out, top_row_size + 1);
        let right_child = column_of(&laid_out, top_row_size + 2);
        prop_assert!(left_child < middle, "{left_child} {middle}");
        prop_assert!(middle < right_child, "{middle} {right_child}");
    }

    #[test]
    fn test_find_agent_index_property_siblings_keep_the_list_order(
        workflow in (SMALLEST_SIBLING_COUNT..=LARGEST_SIBLING_COUNT)
            .prop_flat_map(|child_count| shuffled(siblings(child_count))),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let parent_id = agent_identifier(0);
        let mut previous_column = f64::NEG_INFINITY;
        for agent in &laid_out.agents {
            if agent.id == parent_id {
                continue;
            }
            let column = read_column(agent);
            prop_assert!(column > previous_column);
            previous_column = column;
        }
    }

    #[test]
    fn test_find_agent_index_property_reversed_steps_mirror_their_columns(
        step_count in 1..=LARGEST_SIBLING_COUNT,
    ) {
        let workflow = routing_workflow(step_count, Vec::new());
        let mut reversed_agents = workflow.agents.clone();
        reversed_agents.reverse();
        let reversed = workflow_from_parts(reversed_agents, Vec::new());

        let laid_out = lay_out_workflow(&workflow);
        let reversed_layout = lay_out_workflow(&reversed);

        let last_column = measure_count(workflow.agents.len()) - 1.0;
        for agent in &laid_out.agents {
            let mirrored = read_column_of(&reversed_layout, agent.id);
            let expected = last_column - read_column(agent);
            let is_mirrored = mirrored
                .is_some_and(|column| is_same_coordinate(column, expected));
            prop_assert!(is_mirrored);
        }
    }

    #[test]
    fn test_find_agent_index_property_names_and_ids_never_move_a_step(
        workflow in drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let renamed_layout = lay_out_workflow(&rename_everything(&workflow));

        let renamed_agents = &renamed_layout.agents;
        for (agent, renamed) in laid_out.agents.iter().zip(renamed_agents) {
            prop_assert_eq!(agent.position, renamed.position);
        }
    }
}
