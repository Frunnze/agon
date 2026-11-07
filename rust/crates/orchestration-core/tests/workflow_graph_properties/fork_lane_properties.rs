use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, Workflow};
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::branching_strategies::shuffled_fork_workflow;
use crate::fork_reading::{find_root_join, list_fork_ids, read_column_of};
use crate::layout_reading::{
    ROW_PITCH, drafted_workflow, drafted_workflow_without_forks,
    find_widest_row_size, is_same_coordinate, list_branch_heads, list_lanes,
    list_rows, measure_count, read_column,
};
use crate::routing_fixtures::{connect, routing_workflow};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const EXTRA_OUTCOME: &str = "also this way";
const FIRST_OUTCOME: &str = "first";
const SECOND_OUTCOME: &str = "second";
const SMALLEST_CHAIN_BRANCH_COUNT: usize = 2;
const LARGEST_CHAIN_BRANCH_COUNT: usize = 4;
const LARGEST_CHAIN_BRANCH_LENGTH: u128 = 3;
const LARGEST_PREFIX_LENGTH: u128 = 3;
const SIDES_OF_A_ROW: f64 = 2.0;

fn strip_loops(workflow: &Workflow) -> Workflow {
    let forward: Vec<AgentConnection> = workflow
        .connections
        .iter()
        .filter(|connection| !connection.is_loop())
        .cloned()
        .collect();
    workflow_from_parts(workflow.agents.clone(), forward)
}

fn repeat_a_branch(
    workflow: &Workflow,
    pick: prop::sample::Index,
) -> Workflow {
    let branches: Vec<&AgentConnection> = workflow
        .connections
        .iter()
        .filter(|connection| connection.condition.is_some())
        .collect();
    let mut connections = workflow.connections.clone();
    if !branches.is_empty() {
        let picked = branches[pick.index(branches.len())];
        connections.push(AgentConnection {
            condition: Some(EXTRA_OUTCOME.to_owned()),
            ..picked.clone()
        });
    }
    workflow_from_parts(workflow.agents.clone(), connections)
}

fn branch_reached_by_branch(
    prefix_length: u128,
    tail_length: u128,
    outcomes: [Option<&str>; 2],
) -> Workflow {
    let mut connections = Vec::new();
    for number in 1..prefix_length {
        connections.push(connect(number - 1, number, None, None));
    }
    let fork = prefix_length - 1;
    let (first_head, second_head) = (prefix_length, prefix_length + 1);
    connections.push(connect(fork, first_head, outcomes[0], None));
    connections.push(connect(fork, second_head, outcomes[1], None));
    connections.push(connect(first_head, second_head, None, None));
    let mut last = second_head;
    for number in (second_head + 1)..=(second_head + tail_length) {
        connections.push(connect(last, number, None, None));
        last = number;
    }
    routing_workflow(last + 1, connections)
}

fn chain_branches(branch_lengths: &[u128]) -> Workflow {
    let mut connections = Vec::new();
    let mut next_number = 1;
    for (branch_position, branch_length) in branch_lengths.iter().enumerate() {
        let outcome = format!("branch {branch_position}");
        connections.push(connect(0, next_number, Some(&outcome), None));
        for number in (next_number + 1)..(next_number + branch_length) {
            connections.push(connect(number - 1, number, None, None));
        }
        next_number += branch_length;
    }
    routing_workflow(next_number, connections)
}

fn chain_branch_lengths() -> impl Strategy<Value = Vec<u128>> {
    vec(
        1..=LARGEST_CHAIN_BRANCH_LENGTH,
        SMALLEST_CHAIN_BRANCH_COUNT..=LARGEST_CHAIN_BRANCH_COUNT,
    )
}

fn share_every_lane(
    workflow: &Workflow,
    fork_id: WorkflowAgentId,
    join_id: WorkflowAgentId,
) -> bool {
    list_fork_ids(workflow).iter().all(|outer_id| {
        list_lanes(workflow, *outer_id)
            .iter()
            .all(|lane| lane.contains(&fork_id) == lane.contains(&join_id))
    })
}

fn is_centred_and_packed(workflow: &Workflow) -> bool {
    let rows = list_rows(workflow);
    let widest_row_size = find_widest_row_size(&rows);
    rows.iter().all(|row| {
        let free_width =
            measure_count(widest_row_size) - measure_count(row.len());
        let mut expected_column = free_width / SIDES_OF_A_ROW;
        row.iter().all(|agent| {
            let is_expected =
                is_same_coordinate(read_column(agent), expected_column);
            expected_column += 1.0;
            is_expected
        })
    })
}

proptest! {
    #[test]
    fn test_list_branch_heads_property_loops_never_open_a_lane(
        workflow in drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let without_loops = lay_out_workflow(&strip_loops(&workflow));

        prop_assert_eq!(laid_out.agents, without_loops.agents);
    }

    #[test]
    fn test_list_branch_heads_property_plain_connections_open_no_lane(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        prop_assert!(is_centred_and_packed(&laid_out));
    }

    #[test]
    fn test_list_branch_heads_property_a_branch_reached_by_another_is_shared(
        prefix_length in 1..=LARGEST_PREFIX_LENGTH,
        tail_length in 0..=LARGEST_PREFIX_LENGTH,
    ) {
        let outcomes = [Some(FIRST_OUTCOME), Some(SECOND_OUTCOME)];
        let forked =
            branch_reached_by_branch(prefix_length, tail_length, outcomes);
        let plain =
            branch_reached_by_branch(prefix_length, tail_length, [None; 2]);

        let forked_layout = lay_out_workflow(&forked);
        let plain_layout = lay_out_workflow(&plain);

        prop_assert_eq!(forked_layout.agents, plain_layout.agents);
    }

    #[test]
    fn test_list_fork_lanes_property_a_repeated_branch_adds_no_lane(
        workflow in shuffled_fork_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let repeated = repeat_a_branch(&workflow, pick);
        let repeated_layout = lay_out_workflow(&repeated);

        prop_assert_eq!(laid_out.agents, repeated_layout.agents);
    }

    #[test]
    fn test_list_fork_lanes_property_every_join_sits_under_its_fork(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let Some(join_id) = find_root_join(&laid_out, fork_id) else {
                continue;
            };
            if !share_every_lane(&laid_out, fork_id, join_id) {
                continue;
            }
            let fork_column = read_column_of(&laid_out, fork_id);
            let join_column = read_column_of(&laid_out, join_id);
            prop_assert_eq!(fork_column, join_column);
        }
    }

    #[test]
    fn test_list_fork_lanes_property_heads_open_the_row_under_the_fork(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork in &laid_out.agents {
            let heads = list_branch_heads(&laid_out, fork.id);
            let mut head_columns = Vec::new();
            for head_id in heads {
                let Some(head) = laid_out.agents.iter().find(|agent| {
                    agent.id == head_id
                }) else {
                    continue;
                };
                let row_below = fork.position.vertical + ROW_PITCH;
                let head_vertical = head.position.vertical;
                prop_assert!(is_same_coordinate(head_vertical, row_below));
                head_columns.push(read_column(head));
            }
            head_columns.sort_by(f64::total_cmp);
            for neighbours in head_columns.windows(2) {
                prop_assert!(neighbours[1] - neighbours[0] >= 1.0);
            }
        }
    }

    #[test]
    fn test_list_lanes_of_fork_property_chain_branches_keep_their_columns(
        branch_lengths in chain_branch_lengths(),
    ) {
        let laid_out = lay_out_workflow(&chain_branches(&branch_lengths));

        let mut next_number = 1;
        let mut lane_column = 0.0;
        for branch_length in &branch_lengths {
            for number in next_number..(next_number + branch_length) {
                let step_id = agent_identifier(number);
                let column = read_column_of(&laid_out, step_id);
                prop_assert_eq!(column, Some(lane_column));
            }
            next_number += branch_length;
            lane_column += 1.0;
        }
        let fork_column = (lane_column - 1.0) / SIDES_OF_A_ROW;
        prop_assert_eq!(
            read_column_of(&laid_out, agent_identifier(0)),
            Some(fork_column)
        );
    }
}
