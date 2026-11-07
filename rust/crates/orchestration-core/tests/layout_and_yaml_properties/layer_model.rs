use std::collections::{BTreeMap, BTreeSet};

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{CanvasPosition, Workflow};
use orchestration_core::workflow_graph::forward_connections;

use crate::layout_reading::ROW_PITCH;

pub type ExpectedRows = BTreeMap<WorkflowAgentId, usize>;

pub fn list_positions(workflow: &Workflow) -> Vec<CanvasPosition> {
    let mut positions = Vec::new();
    for agent in &workflow.agents {
        positions.push(agent.position);
    }
    positions
}

pub fn list_verticals(workflow: &Workflow) -> Vec<f64> {
    let mut verticals = Vec::new();
    for agent in &workflow.agents {
        verticals.push(agent.position.vertical);
    }
    verticals
}

pub fn row_vertical(row: usize) -> f64 {
    let mut vertical = 0.0;
    for _ in 0..row {
        vertical += ROW_PITCH;
    }
    vertical
}

pub fn expect_rows(workflow: &Workflow) -> ExpectedRows {
    let mut expected_rows = ExpectedRows::new();
    for agent in &workflow.agents {
        measure_depth(workflow, agent.id, &mut expected_rows);
    }
    expected_rows
}

fn measure_depth(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
    expected_rows: &mut ExpectedRows,
) -> usize {
    if let Some(known_depth) = expected_rows.get(&agent_id) {
        return *known_depth;
    }

    let known_ids = list_agent_ids(workflow);
    let mut depth = 0;
    for connection in forward_connections(workflow) {
        let is_known_input =
            connection.to == agent_id && known_ids.contains(&connection.from);
        if is_known_input {
            let input_depth =
                measure_depth(workflow, connection.from, expected_rows);
            depth = depth.max(input_depth + 1);
        }
    }
    expected_rows.insert(agent_id, depth);
    depth
}

pub fn list_agent_ids(workflow: &Workflow) -> BTreeSet<WorkflowAgentId> {
    let mut agent_ids = BTreeSet::new();
    for agent in &workflow.agents {
        agent_ids.insert(agent.id);
    }
    agent_ids
}

pub fn find_vertical(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> Option<f64> {
    let found = workflow.agents.iter().find(|agent| agent.id == agent_id);
    found.map(|agent| agent.position.vertical)
}

pub fn list_distinct_rows(workflow: &Workflow) -> Vec<f64> {
    let mut verticals = list_verticals(workflow);
    verticals.sort_by(f64::total_cmp);
    verticals.dedup_by(|first, second| first.total_cmp(second).is_eq());
    verticals
}
