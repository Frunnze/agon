use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::{
    find_agent_by_id, forward_reachable_agents,
};

use crate::layout_reading::{
    COLUMN_PITCH, StepIds, find_span, is_same_coordinate, list_branch_heads,
    list_columns_of, list_lanes, list_rows, measure_count, read_column,
};

const DRAWN_STEP_WIDTH: f64 = 160.0;
const SIDES_OF_A_ROW: f64 = 2.0;

pub struct LaneRow {
    pub centre: f64,
    pub step_count: usize,
}

pub fn list_fork_ids(workflow: &Workflow) -> Vec<WorkflowAgentId> {
    let mut fork_ids = Vec::new();
    for agent in &workflow.agents {
        if !list_branch_heads(workflow, agent.id).is_empty() {
            fork_ids.push(agent.id);
        }
    }
    fork_ids
}

pub fn is_leaf_lane(workflow: &Workflow, lane: &StepIds) -> bool {
    lane.iter()
        .all(|step_id| list_branch_heads(workflow, *step_id).is_empty())
}

pub fn list_lane_rows(workflow: &Workflow, lane: &StepIds) -> Vec<LaneRow> {
    let mut verticals: Vec<f64> = Vec::new();
    for step_id in lane {
        if let Some(step) = find_agent_by_id(workflow, *step_id) {
            verticals.push(step.position.vertical);
        }
    }
    verticals.sort_by(f64::total_cmp);
    verticals.dedup_by(|first, second| is_same_coordinate(*first, *second));

    let mut lane_rows = Vec::new();
    for vertical in verticals {
        let mut row_steps = StepIds::new();
        for step_id in lane {
            let is_in_row =
                find_agent_by_id(workflow, *step_id).is_some_and(|step| {
                    is_same_coordinate(step.position.vertical, vertical)
                });
            if is_in_row {
                row_steps.insert(*step_id);
            }
        }
        let columns = list_columns_of(workflow, &row_steps);
        if let Some((leftmost, rightmost)) = find_span(&columns) {
            lane_rows.push(LaneRow {
                centre: (leftmost + rightmost) / SIDES_OF_A_ROW,
                step_count: row_steps.len(),
            });
        }
    }
    lane_rows
}

pub fn measure_leaf_lane_width(lane_rows: &[LaneRow]) -> f64 {
    let mut widest_count = 0;
    for lane_row in lane_rows {
        widest_count = widest_count.max(lane_row.step_count);
    }
    measure_count(widest_count)
}

pub fn are_lanes_apart(
    workflow: &Workflow,
    first: &StepIds,
    second: &StepIds,
) -> bool {
    let first_span = find_span(&list_columns_of(workflow, first));
    let second_span = find_span(&list_columns_of(workflow, second));
    let (Some(first_span), Some(second_span)) = (first_span, second_span)
    else {
        return true;
    };
    let width_in_columns = DRAWN_STEP_WIDTH / COLUMN_PITCH;
    let is_first_left = first_span.1 + width_in_columns <= second_span.0;
    let is_second_left = second_span.1 + width_in_columns <= first_span.0;
    is_first_left || is_second_left
}

pub fn list_lane_steps_of_fork(
    workflow: &Workflow,
    fork_id: WorkflowAgentId,
) -> StepIds {
    let mut lane_steps = StepIds::new();
    for lane in list_lanes(workflow, fork_id) {
        lane_steps.extend(lane);
    }
    lane_steps
}

pub fn find_root_join(
    workflow: &Workflow,
    fork_id: WorkflowAgentId,
) -> Option<WorkflowAgentId> {
    let heads = list_branch_heads(workflow, fork_id);
    let mut shared: Option<StepIds> = None;
    for head in heads {
        let reached = forward_reachable_agents(workflow, head);
        let narrowed = match shared {
            Some(current) => current.intersection(&reached).copied().collect(),
            None => reached,
        };
        shared = Some(narrowed);
    }
    let shared_steps = shared?;
    let mut join: Option<(f64, WorkflowAgentId)> = None;
    for step_id in shared_steps {
        let Some(step) = find_agent_by_id(workflow, step_id) else {
            continue;
        };
        let vertical = step.position.vertical;
        let is_higher =
            join.is_none_or(|(join_vertical, _)| vertical < join_vertical);
        if is_higher {
            join = Some((vertical, step_id));
        }
    }
    join.map(|(_, join_id)| join_id)
}

pub fn read_column_of(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> Option<f64> {
    find_agent_by_id(workflow, agent_id).map(read_column)
}

pub fn measure_centre_distance(first_width: f64, second_width: f64) -> f64 {
    (first_width + second_width) / SIDES_OF_A_ROW
}

pub fn is_lane_left_of(
    workflow: &Workflow,
    first: &StepIds,
    second: &StepIds,
) -> bool {
    let first_span = find_span(&list_columns_of(workflow, first));
    let second_span = find_span(&list_columns_of(workflow, second));
    let (Some(first_span), Some(second_span)) = (first_span, second_span)
    else {
        return true;
    };
    first_span.1 < second_span.0
}

pub fn list_nested_fork_ids(workflow: &Workflow) -> Vec<WorkflowAgentId> {
    let mut nested_fork_ids = Vec::new();
    let fork_ids = list_fork_ids(workflow);
    for fork_id in &fork_ids {
        let is_nested = fork_ids.iter().any(|outer_id| {
            list_lane_steps_of_fork(workflow, *outer_id).contains(fork_id)
        });
        if is_nested {
            nested_fork_ids.push(*fork_id);
        }
    }
    nested_fork_ids
}

pub fn list_steps_in_lanes(workflow: &Workflow) -> StepIds {
    let mut lane_steps = StepIds::new();
    for fork_id in list_fork_ids(workflow) {
        lane_steps.extend(list_lane_steps_of_fork(workflow, fork_id));
    }
    lane_steps
}

pub fn find_first_fork(workflow: &Workflow) -> Option<WorkflowAgentId> {
    let rows = list_rows(workflow);
    rows.iter().find_map(|row| {
        let is_fork = !list_branch_heads(workflow, row[0].id).is_empty();
        is_fork.then_some(row[0].id)
    })
}
