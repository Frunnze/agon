use std::collections::BTreeMap;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::Workflow;

use crate::layout_reading::{StepIds, list_lanes};

type Containers = BTreeMap<WorkflowAgentId, Option<usize>>;

pub struct HeldLane {
    pub fork_id: WorkflowAgentId,
    pub reached_steps: StepIds,
    pub members: StepIds,
}

struct ReachedLane {
    fork_id: WorkflowAgentId,
    steps: StepIds,
}

pub fn list_held_lanes(laid_out: &Workflow) -> Vec<HeldLane> {
    let reached_lanes = list_reached_lanes(laid_out);
    let containers = assign_containers(laid_out, &reached_lanes);

    let mut held_lanes = Vec::new();
    for (lane_index, reached_lane) in reached_lanes.iter().enumerate() {
        let mut members = StepIds::new();
        for agent in &laid_out.agents {
            let chain = list_chain(agent.id, &containers, &reached_lanes);
            if chain.contains(&lane_index) {
                members.insert(agent.id);
            }
        }
        held_lanes.push(HeldLane {
            fork_id: reached_lane.fork_id,
            reached_steps: reached_lane.steps.clone(),
            members,
        });
    }
    held_lanes
}

pub fn list_held_lanes_of(
    held_lanes: &[HeldLane],
    fork_id: WorkflowAgentId,
) -> Vec<&HeldLane> {
    let mut fork_lanes = Vec::new();
    for held_lane in held_lanes {
        if held_lane.fork_id == fork_id {
            fork_lanes.push(held_lane);
        }
    }
    fork_lanes
}

pub fn list_group_members(
    held_lanes: &[HeldLane],
    fork_id: WorkflowAgentId,
) -> StepIds {
    let mut group_members = StepIds::new();
    for held_lane in list_held_lanes_of(held_lanes, fork_id) {
        group_members.extend(&held_lane.members);
    }
    group_members
}

fn list_reached_lanes(workflow: &Workflow) -> Vec<ReachedLane> {
    let mut reached_lanes = Vec::new();
    for fork in &workflow.agents {
        for steps in list_lanes(workflow, fork.id) {
            reached_lanes.push(ReachedLane {
                fork_id: fork.id,
                steps,
            });
        }
    }
    reached_lanes
}

fn assign_containers(
    laid_out: &Workflow,
    reached_lanes: &[ReachedLane],
) -> Containers {
    let mut top_rows_first: Vec<_> = laid_out.agents.iter().collect();
    top_rows_first.sort_by(|first, second| {
        first.position.vertical.total_cmp(&second.position.vertical)
    });

    let mut containers = Containers::new();
    for agent in top_rows_first {
        let container =
            find_smallest_holder(agent.id, reached_lanes, &containers);
        containers.insert(agent.id, container);
    }
    containers
}

fn find_smallest_holder(
    step_id: WorkflowAgentId,
    reached_lanes: &[ReachedLane],
    containers: &Containers,
) -> Option<usize> {
    let mut smallest: Option<usize> = None;
    for (lane_index, reached_lane) in reached_lanes.iter().enumerate() {
        let fork_chain =
            list_chain(reached_lane.fork_id, containers, reached_lanes);
        let is_held_outside = fork_chain.iter().all(|outer_index| {
            reached_lanes[*outer_index].steps.contains(&step_id)
        });
        let can_hold =
            reached_lane.steps.contains(&step_id) && is_held_outside;
        let is_smaller = smallest.is_none_or(|current| {
            reached_lane.steps.len() < reached_lanes[current].steps.len()
        });
        if can_hold && is_smaller {
            smallest = Some(lane_index);
        }
    }
    smallest
}

fn list_chain(
    step_id: WorkflowAgentId,
    containers: &Containers,
    reached_lanes: &[ReachedLane],
) -> Vec<usize> {
    let mut chain = Vec::new();
    let mut container = containers.get(&step_id).copied().flatten();
    while let Some(lane_index) = container {
        chain.push(lane_index);
        let fork_id = reached_lanes[lane_index].fork_id;
        container = containers.get(&fork_id).copied().flatten();
    }
    chain
}
