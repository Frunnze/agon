use std::cmp::Ordering;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{CanvasPosition, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::agents_in_order;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::workflow_strategies::workflow_from_parts;

const COORDINATES: [f64; 5] = [-1.5, -0.0, 0.0, 0.5, 2.0];

pub fn coordinate() -> impl Strategy<Value = f64> {
    prop::sample::select(COORDINATES.to_vec())
}

pub fn canvas_position() -> impl Strategy<Value = CanvasPosition> {
    (coordinate(), coordinate()).prop_map(|(horizontal, vertical)| {
        CanvasPosition {
            horizontal,
            vertical,
        }
    })
}

pub fn repositioned(workflow: Workflow) -> impl Strategy<Value = Workflow> {
    let agent_count = workflow.agents.len();
    vec(canvas_position(), agent_count).prop_map(move |positions| {
        let mut agents = Vec::new();
        for (agent, position) in workflow.agents.iter().zip(positions) {
            agents.push(WorkflowAgent {
                position,
                ..agent.clone()
            });
        }
        workflow_from_parts(agents, workflow.connections.clone())
    })
}

pub fn compare_by_canvas(
    first: &WorkflowAgent,
    second: &WorkflowAgent,
) -> Ordering {
    let vertical =
        first.position.vertical.total_cmp(&second.position.vertical);
    let horizontal = first
        .position
        .horizontal
        .total_cmp(&second.position.horizontal);
    let name = first.name.cmp(&second.name);
    let id = first.id.cmp(&second.id);
    vertical.then(horizontal).then(name).then(id)
}

pub fn list_order_ids(workflow: &Workflow) -> Vec<WorkflowAgentId> {
    agents_in_order(workflow)
        .iter()
        .map(|agent| agent.id)
        .collect()
}
