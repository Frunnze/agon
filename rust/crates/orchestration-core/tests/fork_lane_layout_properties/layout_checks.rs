use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::forward_reachable_agents;

use crate::band_reading::{
    are_groups_apart, do_groups_share_a_row, does_step_overlap,
    find_group_band, is_in_group_rows, is_inside_lanes_of, list_intruders,
};
use crate::fork_reading::{
    are_lanes_apart, is_lane_left_of, list_fork_ids, list_lane_rows,
};
use crate::lane_model::{HeldLane, list_held_lanes, list_held_lanes_of};
use crate::layout_reading::{
    ONE_COLUMN, StepIds, is_same_coordinate, list_branch_heads, list_rows,
    measure_count, read_column,
};

const SIDES_OF_A_ROW: f64 = 2.0;
const LEFT_EDGE: f64 = 0.0;

pub type Violation = Option<String>;

pub fn find_lane_order_violation(laid_out: &Workflow) -> Violation {
    let held_lanes = list_held_lanes(laid_out);
    for fork_id in list_fork_ids(laid_out) {
        let mut filled_lanes = Vec::new();
        for held_lane in list_held_lanes_of(&held_lanes, fork_id) {
            if !held_lane.members.is_empty() {
                filled_lanes.push(&held_lane.members);
            }
        }
        for i in 0..filled_lanes.len() {
            for j in (i + 1)..filled_lanes.len() {
                let (first, second) = (filled_lanes[i], filled_lanes[j]);
                let is_in_order = are_lanes_apart(laid_out, first, second)
                    && is_lane_left_of(laid_out, first, second);
                if !is_in_order {
                    return Some(format!("{first:?} then {second:?}"));
                }
            }
        }
    }
    None
}

pub fn find_intruder_violation(laid_out: &Workflow) -> Violation {
    let held_lanes = list_held_lanes(laid_out);
    for fork_id in list_fork_ids(laid_out) {
        let intruders = list_intruders(laid_out, &held_lanes, fork_id);
        if !intruders.is_empty() {
            return Some(format!("{intruders:?} inside {fork_id:?}"));
        }
    }
    None
}

pub fn find_group_overlap_violation(laid_out: &Workflow) -> Violation {
    let held_lanes = list_held_lanes(laid_out);
    let fork_ids = list_fork_ids(laid_out);
    for first in &fork_ids {
        for second in &fork_ids {
            let are_nested = first == second
                || is_inside_lanes_of(&held_lanes, *first, *second)
                || is_inside_lanes_of(&held_lanes, *second, *first);
            let first_band = find_group_band(laid_out, &held_lanes, *first);
            let second_band = find_group_band(laid_out, &held_lanes, *second);
            let (Some(first_band), Some(second_band)) =
                (first_band, second_band)
            else {
                continue;
            };
            let do_meet = do_groups_share_a_row(&first_band, &second_band);
            let are_apart = are_groups_apart(&first_band, &second_band);
            if !are_nested && do_meet && !are_apart {
                return Some(format!("{first_band:?} and {second_band:?}"));
            }
        }
    }
    None
}

pub fn find_collision(laid_out: &Workflow) -> Violation {
    for row in &list_rows(laid_out) {
        for neighbours in row.windows(2) {
            let gap = read_column(neighbours[1]) - read_column(neighbours[0]);
            if gap < ONE_COLUMN {
                return Some(format!("a gap of {gap}"));
            }
        }
    }
    None
}

pub fn find_bound_violation(laid_out: &Workflow) -> Violation {
    let agent_count = measure_count(laid_out.agents.len());
    for agent in &laid_out.agents {
        let column = read_column(agent);
        let doubled_column = column * SIDES_OF_A_ROW;
        let is_whole_or_half =
            is_same_coordinate(doubled_column, doubled_column.round());
        let is_on_canvas =
            column >= LEFT_EDGE && column + ONE_COLUMN <= agent_count;
        if !is_whole_or_half || !is_on_canvas {
            return Some(format!("column {column} of {agent_count}"));
        }
    }
    None
}

pub fn find_left_edge_violation(laid_out: &Workflow) -> Violation {
    let mut leftmost = f64::INFINITY;
    for agent in &laid_out.agents {
        leftmost = leftmost.min(read_column(agent));
    }
    let touches_left_edge = is_same_coordinate(leftmost, LEFT_EDGE);
    (!touches_left_edge).then(|| format!("the leftmost column is {leftmost}"))
}

pub fn find_leaf_lane_centre_violation(laid_out: &Workflow) -> Violation {
    let held_lanes = list_held_lanes(laid_out);
    for held_lane in &held_lanes {
        if !is_leaf(&held_lanes, &held_lane.members) {
            continue;
        }
        let lane_rows = list_lane_rows(laid_out, &held_lane.members);
        for neighbours in lane_rows.windows(2) {
            let (first, second) = (neighbours[0].centre, neighbours[1].centre);
            if !is_same_coordinate(first, second) {
                return Some(format!("centres {first} and {second}"));
            }
        }
    }
    None
}

pub fn find_free_row_centre_violation(laid_out: &Workflow) -> Violation {
    let held_lanes = list_held_lanes(laid_out);
    let mut centres = Vec::new();
    for row in &list_rows(laid_out) {
        let vertical = row[0].position.vertical;
        if !is_free_row(laid_out, &held_lanes, vertical) {
            continue;
        }
        for neighbours in row.windows(2) {
            let gap = read_column(neighbours[1]) - read_column(neighbours[0]);
            if !is_same_coordinate(gap, ONE_COLUMN) {
                return Some(format!("a gap of {gap} in a free row"));
            }
        }
        let leftmost = read_column(row[0]);
        let rightmost = read_column(row[row.len() - 1]);
        centres.push((leftmost + rightmost) / SIDES_OF_A_ROW);
    }
    for neighbours in centres.windows(2) {
        if !is_same_coordinate(neighbours[0], neighbours[1]) {
            return Some(format!("free row centres {centres:?}"));
        }
    }
    None
}

pub fn find_shared_step_violation(laid_out: &Workflow) -> Violation {
    let held_lanes = list_held_lanes(laid_out);
    for fork_id in list_fork_ids(laid_out) {
        let shared_steps = list_shared_steps(laid_out, fork_id);
        let found = find_inside_steps(laid_out, &held_lanes, fork_id)
            .into_iter()
            .find(|step_id| shared_steps.contains(step_id));
        if let Some(step_id) = found {
            return Some(format!("{step_id:?} is shared by {fork_id:?}"));
        }
    }
    None
}

pub fn find_stranger_violation(laid_out: &Workflow) -> Violation {
    let held_lanes = list_held_lanes(laid_out);
    for fork_id in list_fork_ids(laid_out) {
        let mut reached_steps = StepIds::new();
        for held_lane in list_held_lanes_of(&held_lanes, fork_id) {
            reached_steps.extend(&held_lane.reached_steps);
        }
        let found = find_inside_steps(laid_out, &held_lanes, fork_id)
            .into_iter()
            .find(|step_id| !reached_steps.contains(step_id));
        if let Some(step_id) = found {
            return Some(format!("{step_id:?} is a stranger to {fork_id:?}"));
        }
    }
    None
}

fn find_inside_steps(
    laid_out: &Workflow,
    held_lanes: &[HeldLane],
    fork_id: WorkflowAgentId,
) -> StepIds {
    let mut inside_steps = StepIds::new();
    let Some(band) = find_group_band(laid_out, held_lanes, fork_id) else {
        return inside_steps;
    };
    for agent in &laid_out.agents {
        let is_inside = is_in_group_rows(&band, agent.position.vertical)
            && does_step_overlap(&band, read_column(agent));
        if is_inside {
            inside_steps.insert(agent.id);
        }
    }
    inside_steps
}

fn list_shared_steps(
    laid_out: &Workflow,
    fork_id: WorkflowAgentId,
) -> StepIds {
    let heads = list_branch_heads(laid_out, fork_id);
    let mut shared_steps = StepIds::new();
    for (position, head) in heads.iter().enumerate() {
        let reached = forward_reachable_agents(laid_out, *head);
        for other_head in &heads[position + 1..] {
            let other_reached =
                forward_reachable_agents(laid_out, *other_head);
            shared_steps.extend(reached.intersection(&other_reached));
        }
    }
    shared_steps
}

fn is_leaf(held_lanes: &[HeldLane], members: &StepIds) -> bool {
    held_lanes.iter().all(|held_lane| {
        held_lane.members.is_empty() || !members.contains(&held_lane.fork_id)
    })
}

fn is_free_row(
    laid_out: &Workflow,
    held_lanes: &[HeldLane],
    vertical: f64,
) -> bool {
    for held_lane in held_lanes {
        let has_member_in_row = held_lane.members.iter().any(|member_id| {
            laid_out.agents.iter().any(|agent| {
                agent.id == *member_id
                    && is_same_coordinate(agent.position.vertical, vertical)
            })
        });
        let band = find_group_band(laid_out, held_lanes, held_lane.fork_id);
        let is_group_row =
            band.is_some_and(|band| is_in_group_rows(&band, vertical));
        if has_member_in_row || is_group_row {
            return false;
        }
    }
    true
}
