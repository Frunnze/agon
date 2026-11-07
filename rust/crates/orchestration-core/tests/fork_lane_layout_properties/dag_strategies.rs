use std::collections::{BTreeMap, BTreeSet};
use std::ops::RangeInclusive;

use orchestration_core::workflow::{AgentConnection, Workflow};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::routing_fixtures::{connect, routing_workflow};
use crate::workflow_strategies::workflow_from_parts;

const SMALLEST_STEP_COUNT: u128 = 2;
const LARGEST_STEP_COUNT: u128 = 10;
const LARGEST_CONNECTION_PICKS: usize = 20;
const SMALLEST_WIDE_STEP_COUNT: u128 = 8;
const LARGEST_WIDE_STEP_COUNT: u128 = 14;
const LARGEST_WIDE_CONNECTION_PICKS: usize = 32;
const REPORTED_EXAMPLE_STEP_COUNT: u128 = 8;
const FIRST_OUTCOME: &str = "first";
const SECOND_OUTCOME: &str = "second";
const BRANCH_OUTCOME_PREFIX: &str = "branch";
pub const GROUP_FORK: u128 = 0;
pub const SIDE_ROOT: u128 = 1;
pub const FIRST_LANE_HEAD: u128 = 2;
const LATE_FORK_CHAIN: u128 = 1;

type ConnectionPick = (u128, u128, bool);

pub fn forked_dag_workflow() -> impl Strategy<Value = Workflow> {
    forked_dag_with(
        SMALLEST_STEP_COUNT..=LARGEST_STEP_COUNT,
        LARGEST_CONNECTION_PICKS,
    )
}

pub fn wide_forked_dag_workflow() -> impl Strategy<Value = Workflow> {
    forked_dag_with(
        SMALLEST_WIDE_STEP_COUNT..=LARGEST_WIDE_STEP_COUNT,
        LARGEST_WIDE_CONNECTION_PICKS,
    )
}

fn forked_dag_with(
    step_counts: RangeInclusive<u128>,
    largest_pick_count: usize,
) -> impl Strategy<Value = Workflow> {
    step_counts
        .prop_flat_map(move |step_count| {
            let pick = (0..step_count, 0..step_count, any::<bool>());
            vec(pick, 0..=largest_pick_count)
                .prop_map(move |picks| build_forked_dag(step_count, &picks))
        })
        .prop_flat_map(shuffle_storage)
}

pub fn shuffle_storage(workflow: Workflow) -> impl Strategy<Value = Workflow> {
    (
        Just(workflow.agents).prop_shuffle(),
        Just(workflow.connections).prop_shuffle(),
    )
        .prop_map(|(agents, connections)| {
            workflow_from_parts(agents, connections)
        })
}

pub fn reported_example() -> Workflow {
    routing_workflow(
        REPORTED_EXAMPLE_STEP_COUNT,
        vec![
            connect(0, 2, None, None),
            connect(2, 3, None, None),
            connect(1, 5, Some(FIRST_OUTCOME), None),
            connect(1, 3, Some(SECOND_OUTCOME), None),
        ],
    )
}

pub fn outer_join_through_inner_lane() -> Workflow {
    routing_workflow(
        6,
        vec![
            connect(0, 1, Some(FIRST_OUTCOME), None),
            connect(0, 2, Some(SECOND_OUTCOME), None),
            connect(1, 3, Some(FIRST_OUTCOME), None),
            connect(1, 4, Some(SECOND_OUTCOME), None),
            connect(3, 5, None, None),
            connect(2, 5, None, None),
        ],
    )
}

pub fn forks_sharing_a_head() -> Workflow {
    routing_workflow(
        5,
        vec![
            connect(0, 2, Some(FIRST_OUTCOME), None),
            connect(0, 3, Some(SECOND_OUTCOME), None),
            connect(1, 2, Some(FIRST_OUTCOME), None),
            connect(1, 4, Some(SECOND_OUTCOME), None),
        ],
    )
}

pub fn smaller_lane_beside_a_wider_one() -> Workflow {
    routing_workflow(
        6,
        vec![
            connect(0, 2, Some(FIRST_OUTCOME), None),
            connect(0, 3, Some(SECOND_OUTCOME), None),
            connect(2, 4, None, None),
            connect(1, 4, Some(FIRST_OUTCOME), None),
            connect(1, 5, Some(SECOND_OUTCOME), None),
        ],
    )
}

pub fn side_chain_beside_group(
    lane_length: u128,
    side_length: u128,
) -> Workflow {
    let left_head = FIRST_LANE_HEAD;
    let right_head = left_head + lane_length;
    let side_head = find_side_head(lane_length);
    let step_count = count_side_chain_steps(lane_length, side_length);
    let mut connections = vec![
        connect(GROUP_FORK, left_head, Some(FIRST_OUTCOME), None),
        connect(GROUP_FORK, right_head, Some(SECOND_OUTCOME), None),
        connect(SIDE_ROOT, side_head, None, None),
    ];
    connections.extend(chain_steps(left_head, lane_length));
    connections.extend(chain_steps(right_head, lane_length));
    connections.extend(chain_steps(side_head, side_length));
    routing_workflow(step_count, connections)
}

pub fn two_side_chains_beside_group(
    lane_length: u128,
    other_side_length: u128,
) -> Workflow {
    let one_side = side_chain_beside_group(lane_length, lane_length);
    let other_root = count_side_chain_steps(lane_length, lane_length);
    let other_head = other_root + 1;
    let step_count = other_head + other_side_length;
    let mut connections = one_side.connections;
    connections.push(connect(other_root, other_head, None, None));
    connections.extend(chain_steps(other_head, other_side_length));
    routing_workflow(step_count, connections)
}

pub fn late_fork_beside_group(lane_length: u128) -> Workflow {
    let one_side = side_chain_beside_group(lane_length, LATE_FORK_CHAIN);
    let late_fork = find_side_head(lane_length);
    let first_late_head = late_fork + 1;
    let second_late_head = first_late_head + 1;
    let mut connections = one_side.connections;
    connections.push(connect(
        late_fork,
        first_late_head,
        Some(FIRST_OUTCOME),
        None,
    ));
    connections.push(connect(
        late_fork,
        second_late_head,
        Some(SECOND_OUTCOME),
        None,
    ));
    routing_workflow(second_late_head + 1, connections)
}

pub fn find_side_head(lane_length: u128) -> u128 {
    FIRST_LANE_HEAD + lane_length + lane_length
}

pub fn count_side_chain_steps(lane_length: u128, side_length: u128) -> u128 {
    find_side_head(lane_length) + side_length
}

fn chain_steps(head: u128, length: u128) -> Vec<AgentConnection> {
    let mut connections = Vec::new();
    for step in (head + 1)..(head + length) {
        connections.push(connect(step - 1, step, None, None));
    }
    connections
}

fn build_forked_dag(step_count: u128, picks: &[ConnectionPick]) -> Workflow {
    let mut used_pairs = BTreeSet::new();
    let mut outcome_counts: BTreeMap<u128, usize> = BTreeMap::new();
    let mut connections: Vec<AgentConnection> = Vec::new();
    for (first, second, is_conditioned) in picks {
        let upstream = *first.min(second);
        let downstream = *first.max(second);
        let is_new_pair = used_pairs.insert((upstream, downstream));
        if upstream == downstream || !is_new_pair {
            continue;
        }

        let condition = is_conditioned.then(|| {
            let outgoing_count = outcome_counts.entry(upstream).or_default();
            *outgoing_count += 1;
            format!("{BRANCH_OUTCOME_PREFIX} {upstream}-{outgoing_count}")
        });
        connections.push(connect(
            upstream,
            downstream,
            condition.as_deref(),
            None,
        ));
    }
    routing_workflow(step_count, connections)
}
