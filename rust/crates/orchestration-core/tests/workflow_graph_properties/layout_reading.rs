use std::collections::BTreeSet;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::{
    find_agent_by_id, forward_connections, forward_reachable_agents,
};
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;

use crate::branching_strategies::{
    BranchingPlan, branching_plan_with_agent_counts, build_branching_workflow,
};
use crate::routing_fixtures::{connect, routing_workflow};

pub const COLUMN_PITCH: f64 = 208.0;
pub const ROW_PITCH: f64 = 152.0;
pub const ONE_COLUMN: f64 = 1.0;
pub const HOSTILE_OUTCOME: &str = "go";
const SMALLEST_DRAFTED_STEP_COUNT: usize = 1;
const LARGEST_DRAFTED_STEP_COUNT: usize = 10;
const LARGEST_HOSTILE_AGENT_COUNT: u128 = 8;
const LARGEST_HOSTILE_CONNECTION_COUNT: usize = 16;
const LARGEST_HOSTILE_ROUND_LIMIT: u32 = 11;

pub type StepIds = BTreeSet<WorkflowAgentId>;
pub type LaidOutRow<'workflow> = Vec<&'workflow WorkflowAgent>;

pub fn drafted_workflow() -> impl Strategy<Value = Workflow> {
    branching_plan_with_agent_counts(
        SMALLEST_DRAFTED_STEP_COUNT..=LARGEST_DRAFTED_STEP_COUNT,
    )
    .prop_map(|plan| build_branching_workflow(&plan))
}

pub fn drafted_workflow_without_forks() -> impl Strategy<Value = Workflow> {
    branching_plan_with_agent_counts(
        SMALLEST_DRAFTED_STEP_COUNT..=LARGEST_DRAFTED_STEP_COUNT,
    )
    .prop_map(|plan| {
        let conditioned = vec![false; plan.conditioned.len()];
        build_branching_workflow(&BranchingPlan {
            conditioned,
            ..plan
        })
    })
}

pub fn hostile_workflow() -> impl Strategy<Value = Workflow> {
    (1..=LARGEST_HOSTILE_AGENT_COUNT).prop_flat_map(|agent_count| {
        let connection = (
            0..agent_count,
            0..agent_count,
            any::<bool>(),
            option::of(0..=LARGEST_HOSTILE_ROUND_LIMIT),
        );
        vec(connection, 0..=LARGEST_HOSTILE_CONNECTION_COUNT).prop_map(
            move |picks| {
                let mut connections = Vec::new();
                for (from, to, is_conditioned, round_limit) in picks {
                    let condition = is_conditioned.then_some(HOSTILE_OUTCOME);
                    connections.push(connect(
                        from,
                        to,
                        condition,
                        round_limit,
                    ));
                }
                routing_workflow(agent_count, connections)
            },
        )
    })
}

pub fn read_column(agent: &WorkflowAgent) -> f64 {
    agent.position.horizontal / COLUMN_PITCH
}

pub fn is_same_coordinate(first: f64, second: f64) -> bool {
    first.total_cmp(&second).is_eq()
}

pub fn measure_count(count: usize) -> f64 {
    let mut width = 0.0;
    for _ in 0..count {
        width += ONE_COLUMN;
    }
    width
}

pub fn list_rows(workflow: &Workflow) -> Vec<LaidOutRow<'_>> {
    let mut verticals: Vec<f64> = Vec::new();
    for agent in &workflow.agents {
        verticals.push(agent.position.vertical);
    }
    verticals.sort_by(f64::total_cmp);
    verticals.dedup_by(|first, second| is_same_coordinate(*first, *second));

    let mut rows = Vec::new();
    for vertical in verticals {
        let mut row: LaidOutRow<'_> = Vec::new();
        for agent in &workflow.agents {
            if is_same_coordinate(agent.position.vertical, vertical) {
                row.push(agent);
            }
        }
        row.sort_by(|first, second| {
            first
                .position
                .horizontal
                .total_cmp(&second.position.horizontal)
        });
        rows.push(row);
    }
    rows
}

pub fn find_widest_row_size(rows: &[LaidOutRow<'_>]) -> usize {
    let mut widest_row_size = 0;
    for row in rows {
        widest_row_size = widest_row_size.max(row.len());
    }
    widest_row_size
}

pub fn find_row_index(
    rows: &[LaidOutRow<'_>],
    agent_id: WorkflowAgentId,
) -> Option<usize> {
    rows.iter()
        .position(|row| row.iter().any(|agent| agent.id == agent_id))
}

pub fn list_branch_heads(
    workflow: &Workflow,
    fork_id: WorkflowAgentId,
) -> Vec<WorkflowAgentId> {
    let mut heads = Vec::new();
    for connection in forward_connections(workflow) {
        let is_branch =
            connection.from == fork_id && connection.condition.is_some();
        if is_branch && !heads.contains(&connection.to) {
            heads.push(connection.to);
        }
    }
    heads
}

pub fn list_lanes(
    workflow: &Workflow,
    fork_id: WorkflowAgentId,
) -> Vec<StepIds> {
    let heads = list_branch_heads(workflow, fork_id);
    let mut reached_per_head = Vec::new();
    for head in &heads {
        reached_per_head.push(forward_reachable_agents(workflow, *head));
    }

    let mut lanes = Vec::new();
    for (position, reached) in reached_per_head.iter().enumerate() {
        let mut lane = reached.clone();
        for (other_position, other) in reached_per_head.iter().enumerate() {
            if other_position != position {
                lane.retain(|step| !other.contains(step));
            }
        }
        lanes.push(lane);
    }
    lanes
}

pub fn list_columns_of(workflow: &Workflow, steps: &StepIds) -> Vec<f64> {
    let mut columns = Vec::new();
    for step_id in steps {
        if let Some(step) = find_agent_by_id(workflow, *step_id) {
            columns.push(read_column(step));
        }
    }
    columns
}

pub fn find_span(columns: &[f64]) -> Option<(f64, f64)> {
    let mut span: Option<(f64, f64)> = None;
    for column in columns {
        let widened = match span {
            Some((leftmost, rightmost)) => {
                (leftmost.min(*column), rightmost.max(*column))
            }
            None => (*column, *column),
        };
        span = Some(widened);
    }
    span
}
