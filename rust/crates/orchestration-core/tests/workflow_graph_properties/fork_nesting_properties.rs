use orchestration_core::workflow::{AgentConnection, StepKind, Workflow};
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::branching_strategies::shuffled_fork_workflow;
use crate::fork_reading::{
    are_lanes_apart, is_lane_left_of, is_leaf_lane, list_fork_ids,
    list_lane_rows, list_nested_fork_ids,
};
use crate::layout_reading::{
    StepIds, find_row_index, hostile_workflow, is_same_coordinate,
    list_branch_heads, list_lanes, list_rows, measure_count, read_column,
};
use crate::routing_fixtures::{connect, routing_agent, routing_workflow};
use crate::workflow_strategies::workflow_from_parts;

const SHARED_OUTCOME: &str = "shared";
const OWN_OUTCOME: &str = "own";
const LARGEST_EXTRA_STEPS: u128 = 4;
const FIRST_EXTRA_STEP: u128 = 5;
const EXTRA_STEP_PARENT_OFFSET: u128 = 3;

fn count_agents(workflow: &Workflow) -> u128 {
    let mut agent_count = 0;
    for _ in &workflow.agents {
        agent_count += 1;
    }
    agent_count
}

fn list_sink_positions(workflow: &Workflow) -> Vec<usize> {
    let mut sinks = Vec::new();
    for (position, agent) in workflow.agents.iter().enumerate() {
        let has_output = workflow
            .connections
            .iter()
            .any(|connection| connection.from == agent.id);
        if !has_output {
            sinks.push(position);
        }
    }
    sinks
}

fn extend_a_sink(workflow: &Workflow, pick: prop::sample::Index) -> Workflow {
    let sinks = list_sink_positions(workflow);
    let sink_id = workflow.agents[sinks[pick.index(sinks.len())]].id;
    let extension = routing_agent(count_agents(workflow), StepKind::Agent);
    let mut connections = workflow.connections.clone();
    connections.push(AgentConnection::plain(sink_id, extension.id));
    let mut agents = workflow.agents.clone();
    agents.push(extension);
    workflow_from_parts(agents, connections)
}

fn without_heads(workflow: &Workflow, lane: &StepIds) -> StepIds {
    let mut deep_steps = lane.clone();
    for fork in &workflow.agents {
        for head in list_branch_heads(workflow, fork.id) {
            deep_steps.remove(&head);
        }
    }
    deep_steps
}

fn has_fork_inside(workflow: &Workflow, lane: &StepIds) -> bool {
    !is_leaf_lane(workflow, lane)
}

fn forks_sharing_a_branch(extra_steps: u128) -> Workflow {
    let mut connections = vec![
        connect(0, 2, Some(SHARED_OUTCOME), None),
        connect(0, 3, Some(OWN_OUTCOME), None),
        connect(1, 2, Some(SHARED_OUTCOME), None),
        connect(1, 4, Some(OWN_OUTCOME), None),
    ];
    let end = FIRST_EXTRA_STEP + extra_steps;
    for number in FIRST_EXTRA_STEP..end {
        let parent = number - EXTRA_STEP_PARENT_OFFSET;
        connections.push(connect(parent, number, None, None));
    }
    routing_workflow(end, connections)
}

proptest! {
    #[test]
    fn test_list_reachable_steps_property_deep_steps_stay_in_their_lane(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            for i in 0..lanes.len() {
                for j in (i + 1)..lanes.len() {
                    let deep_first = without_heads(&laid_out, &lanes[i]);
                    let deep_second = without_heads(&laid_out, &lanes[j]);
                    let is_first_left =
                        is_lane_left_of(&laid_out, &deep_first, &lanes[j]);
                    let is_second_right =
                        is_lane_left_of(&laid_out, &lanes[i], &deep_second);
                    prop_assert!(is_first_left);
                    prop_assert!(is_second_right);
                }
            }
        }
    }

    #[test]
    fn test_list_reachable_steps_property_lanes_with_forks_keep_apart(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            for i in 0..lanes.len() {
                for j in 0..lanes.len() {
                    if i == j || !has_fork_inside(&laid_out, &lanes[i]) {
                        continue;
                    }
                    let are_apart =
                        are_lanes_apart(&laid_out, &lanes[i], &lanes[j]);
                    prop_assert!(are_apart);
                }
            }
        }
    }

    #[test]
    fn test_list_reachable_steps_property_an_extended_branch_keeps_its_lane(
        workflow in shuffled_fork_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let extended = lay_out_workflow(&extend_a_sink(&workflow, pick));

        for fork_id in list_fork_ids(&extended) {
            let lanes = list_lanes(&extended, fork_id);
            for i in 0..lanes.len() {
                for j in (i + 1)..lanes.len() {
                    let is_left =
                        is_lane_left_of(&extended, &lanes[i], &lanes[j]);
                    prop_assert!(is_left);
                }
            }
        }
    }

    #[test]
    fn test_find_innermost_lane_property_inner_lanes_keep_apart(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_nested_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            for i in 0..lanes.len() {
                for j in (i + 1)..lanes.len() {
                    let is_left =
                        is_lane_left_of(&laid_out, &lanes[i], &lanes[j]);
                    prop_assert!(is_left);
                }
            }
        }
    }

    #[test]
    fn test_find_innermost_lane_property_inner_leaf_lanes_keep_one_centre(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_nested_fork_ids(&laid_out) {
            for lane in list_lanes(&laid_out, fork_id) {
                if !is_leaf_lane(&laid_out, &lane) {
                    continue;
                }
                let lane_rows = list_lane_rows(&laid_out, &lane);
                for neighbours in lane_rows.windows(2) {
                    let are_aligned = is_same_coordinate(
                        neighbours[0].centre,
                        neighbours[1].centre,
                    );
                    prop_assert!(are_aligned);
                }
            }
        }
    }

    #[test]
    fn test_find_innermost_lane_property_a_shared_branch_never_overlaps(
        extra_steps in 0..=LARGEST_EXTRA_STEPS,
        shuffled_agents in
            Just(forks_sharing_a_branch(LARGEST_EXTRA_STEPS).agents)
                .prop_shuffle(),
    ) {
        let workflow = forks_sharing_a_branch(extra_steps);
        let kept_agents: Vec<_> = shuffled_agents
            .into_iter()
            .filter(|agent| workflow.agents.contains(agent))
            .collect();
        let shuffled = workflow_from_parts(kept_agents, workflow.connections);

        let laid_out = lay_out_workflow(&shuffled);

        let rows = list_rows(&laid_out);
        let agent_count = measure_count(laid_out.agents.len());
        for row in &rows {
            for neighbours in row.windows(2) {
                let gap =
                    read_column(neighbours[1]) - read_column(neighbours[0]);
                prop_assert!(gap >= 1.0, "{gap}");
            }
        }
        for agent in &laid_out.agents {
            prop_assert!(find_row_index(&rows, agent.id).is_some());
            prop_assert!(read_column(agent) + 1.0 <= agent_count);
        }
    }

    #[test]
    fn test_find_innermost_lane_property_hostile_lanes_stay_on_the_canvas(
        workflow in hostile_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for agent in &laid_out.agents {
            prop_assert!(agent.position.horizontal >= 0.0);
            prop_assert!(agent.position.vertical >= 0.0);
            prop_assert!(agent.position.horizontal.is_finite());
        }
    }
}
