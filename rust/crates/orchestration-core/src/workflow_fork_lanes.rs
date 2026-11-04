use std::cmp::Reverse;
use std::collections::BTreeSet;

use crate::workflow_layers::{ForwardLink, goes_down};

type StepIndexes = BTreeSet<usize>;

pub(crate) struct ForkLane {
    pub(crate) fork_index: usize,
    pub(crate) members: StepIndexes,
}

pub(crate) fn list_fork_lanes(
    links: &[ForwardLink],
    layers: &[usize],
) -> Vec<ForkLane> {
    let reachable = list_reachable_steps(links, layers);

    let mut lanes = Vec::new();
    for fork_index in 0..layers.len() {
        let heads = list_branch_heads(fork_index, links, layers);
        for head in &heads {
            let mut members = reachable[*head].clone();
            for other_head in &heads {
                if other_head != head {
                    let reached_by_other = &reachable[*other_head];
                    members.retain(|step| !reached_by_other.contains(step));
                }
            }
            lanes.push(ForkLane {
                fork_index,
                members,
            });
        }
    }
    lanes
}

pub(crate) fn find_lane_of_each_step(
    lanes: &[ForkLane],
    agent_count: usize,
) -> Vec<Option<usize>> {
    let mut step_lanes = Vec::new();
    for step_index in 0..agent_count {
        step_lanes.push(find_innermost_lane(step_index, lanes));
    }
    step_lanes
}

fn list_reachable_steps(
    links: &[ForwardLink],
    layers: &[usize],
) -> Vec<StepIndexes> {
    let mut deepest_first: Vec<usize> = (0..layers.len()).collect();
    deepest_first.sort_by_key(|step_index| Reverse(layers[*step_index]));

    let mut reachable = vec![StepIndexes::new(); layers.len()];
    for step_index in deepest_first {
        let mut reached = StepIndexes::from([step_index]);
        for link in links {
            let is_downward_output =
                link.upstream_index == step_index && goes_down(link, layers);
            if is_downward_output {
                reached.extend(&reachable[link.downstream_index]);
            }
        }
        reachable[step_index] = reached;
    }
    reachable
}

fn list_branch_heads(
    fork_index: usize,
    links: &[ForwardLink],
    layers: &[usize],
) -> Vec<usize> {
    let mut heads = Vec::new();
    for link in links {
        let is_branch = link.upstream_index == fork_index
            && link.is_conditional
            && goes_down(link, layers);
        if is_branch && !heads.contains(&link.downstream_index) {
            heads.push(link.downstream_index);
        }
    }
    heads
}

fn find_innermost_lane(
    step_index: usize,
    lanes: &[ForkLane],
) -> Option<usize> {
    let mut innermost: Option<usize> = None;
    for (lane_index, lane) in lanes.iter().enumerate() {
        let is_narrower = innermost.is_none_or(|current| {
            lane.members.len() < lanes[current].members.len()
        });
        if is_narrower && lane.members.contains(&step_index) {
            innermost = Some(lane_index);
        }
    }
    innermost
}
