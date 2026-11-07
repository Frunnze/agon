use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::find_agent_by_id;

use crate::lane_model::{HeldLane, list_group_members};
use crate::layout_reading::{
    COLUMN_PITCH, ROW_PITCH, StepIds, find_span, list_columns_of, read_column,
};

const DRAWN_STEP_WIDTH: f64 = 160.0;

#[derive(Clone, Copy, Debug)]
pub struct GroupBand {
    pub first_vertical: f64,
    pub last_vertical: f64,
    pub leftmost: f64,
    pub rightmost: f64,
}

pub fn measure_drawn_width() -> f64 {
    DRAWN_STEP_WIDTH / COLUMN_PITCH
}

pub fn find_group_band(
    laid_out: &Workflow,
    held_lanes: &[HeldLane],
    fork_id: WorkflowAgentId,
) -> Option<GroupBand> {
    let members = list_group_members(held_lanes, fork_id);
    let fork = find_agent_by_id(laid_out, fork_id)?;
    let (leftmost, rightmost) =
        find_span(&list_columns_of(laid_out, &members))?;
    let mut last_vertical = fork.position.vertical;
    for member_id in &members {
        if let Some(member) = find_agent_by_id(laid_out, *member_id) {
            last_vertical = last_vertical.max(member.position.vertical);
        }
    }
    Some(GroupBand {
        first_vertical: fork.position.vertical + ROW_PITCH,
        last_vertical,
        leftmost,
        rightmost,
    })
}

pub fn is_in_group_rows(band: &GroupBand, vertical: f64) -> bool {
    band.first_vertical <= vertical && vertical <= band.last_vertical
}

pub fn does_step_overlap(band: &GroupBand, column: f64) -> bool {
    let drawn_width = measure_drawn_width();
    column + drawn_width > band.leftmost
        && column < band.rightmost + drawn_width
}

pub fn do_groups_share_a_row(first: &GroupBand, second: &GroupBand) -> bool {
    first.first_vertical <= second.last_vertical
        && second.first_vertical <= first.last_vertical
}

pub fn are_groups_apart(first: &GroupBand, second: &GroupBand) -> bool {
    let drawn_width = measure_drawn_width();
    let is_first_left = first.rightmost + drawn_width <= second.leftmost;
    let is_second_left = second.rightmost + drawn_width <= first.leftmost;
    is_first_left || is_second_left
}

pub fn list_intruders(
    laid_out: &Workflow,
    held_lanes: &[HeldLane],
    fork_id: WorkflowAgentId,
) -> StepIds {
    let mut intruders = StepIds::new();
    let Some(band) = find_group_band(laid_out, held_lanes, fork_id) else {
        return intruders;
    };
    let members = list_group_members(held_lanes, fork_id);
    for agent in &laid_out.agents {
        let is_inside = is_in_group_rows(&band, agent.position.vertical)
            && does_step_overlap(&band, read_column(agent));
        if is_inside && !members.contains(&agent.id) {
            intruders.insert(agent.id);
        }
    }
    intruders
}

pub fn is_inside_lanes_of(
    held_lanes: &[HeldLane],
    step_id: WorkflowAgentId,
    fork_id: WorkflowAgentId,
) -> bool {
    list_group_members(held_lanes, fork_id).contains(&step_id)
}
