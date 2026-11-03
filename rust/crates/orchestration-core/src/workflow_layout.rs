use std::cmp::Ordering;

use crate::identifiers::WorkflowAgentId;
use crate::workflow::{CanvasPosition, Workflow, WorkflowAgent};
use crate::workflow_graph::forward_connections;

const STEP_WIDTH: f64 = 160.0;
const STEP_HEIGHT: f64 = 88.0;
const GAP_BETWEEN_COLUMNS: f64 = 48.0;
const GAP_BETWEEN_ROWS: f64 = 64.0;
const COLUMN_PITCH: f64 = STEP_WIDTH + GAP_BETWEEN_COLUMNS;
const ROW_PITCH: f64 = STEP_HEIGHT + GAP_BETWEEN_ROWS;
const SIDES_OF_A_ROW: f64 = 2.0;
const TOP_LAYER: usize = 0;
const ONE_LAYER: usize = 1;
const FIRST_SLOT: f64 = 0.0;
const SLOT_STEP: f64 = 1.0;
const ONE_UPSTREAM_STEP: f64 = 1.0;
const CANVAS_ORIGIN: CanvasPosition = CanvasPosition {
    horizontal: 0.0,
    vertical: 0.0,
};

#[derive(PartialEq, Eq)]
struct ForwardLink {
    upstream_index: usize,
    downstream_index: usize,
}

struct RankedStep {
    average_upstream_slot: f64,
    agent_index: usize,
}

#[must_use]
pub fn lay_out_workflow(workflow: &Workflow) -> Workflow {
    let agent_count = workflow.agents.len();
    let links = list_forward_links(workflow);
    let layers = assign_layers(agent_count, &links);
    let rows = order_rows(&layers, &links);
    let positions = place_rows(&rows, agent_count);

    let mut agents = Vec::new();
    for (agent, position) in workflow.agents.iter().zip(positions) {
        agents.push(WorkflowAgent {
            position,
            ..agent.clone()
        });
    }
    Workflow {
        agents,
        ..workflow.clone()
    }
}

fn list_forward_links(workflow: &Workflow) -> Vec<ForwardLink> {
    let mut links = Vec::new();
    for connection in forward_connections(workflow) {
        let upstream = find_agent_index(&workflow.agents, connection.from);
        let downstream = find_agent_index(&workflow.agents, connection.to);
        if let (Some(upstream_index), Some(downstream_index)) =
            (upstream, downstream)
        {
            links.push(ForwardLink {
                upstream_index,
                downstream_index,
            });
        }
    }
    links
}

fn find_agent_index(
    agents: &[WorkflowAgent],
    agent_id: WorkflowAgentId,
) -> Option<usize> {
    agents.iter().position(|agent| agent.id == agent_id)
}

fn assign_layers(agent_count: usize, links: &[ForwardLink]) -> Vec<usize> {
    let mut layers = vec![TOP_LAYER; agent_count];
    for _ in 0..agent_count {
        for link in links {
            let below_upstream = layers[link.upstream_index] + ONE_LAYER;
            let current_layer = layers[link.downstream_index];
            layers[link.downstream_index] = current_layer.max(below_upstream);
        }
    }
    layers
}

fn order_rows(layers: &[usize], links: &[ForwardLink]) -> Vec<Vec<usize>> {
    let deepest_layer = layers.iter().max();
    let row_count = deepest_layer.map_or(0, |deepest| deepest + ONE_LAYER);

    let mut rows: Vec<Vec<usize>> = Vec::new();
    for layer in 0..row_count {
        let mut members = Vec::new();
        for (agent_index, agent_layer) in layers.iter().enumerate() {
            if *agent_layer == layer {
                members.push(agent_index);
            }
        }
        let ordered_members = match rows.last() {
            Some(upper_row) => order_under_row(&members, upper_row, links),
            None => members,
        };
        rows.push(ordered_members);
    }
    rows
}

fn order_under_row(
    members: &[usize],
    upper_row: &[usize],
    links: &[ForwardLink],
) -> Vec<usize> {
    let mut ranked_steps = Vec::new();
    for agent_index in members {
        let average_upstream_slot =
            find_average_upstream_slot(*agent_index, upper_row, links);
        ranked_steps.push(RankedStep {
            average_upstream_slot,
            agent_index: *agent_index,
        });
    }
    ranked_steps.sort_by(compare_ranked_steps);

    let mut ordered_members = Vec::new();
    for ranked_step in ranked_steps {
        ordered_members.push(ranked_step.agent_index);
    }
    ordered_members
}

fn find_average_upstream_slot(
    agent_index: usize,
    upper_row: &[usize],
    links: &[ForwardLink],
) -> f64 {
    let mut slot = FIRST_SLOT;
    let mut slot_total = 0.0;
    let mut upstream_count = 0.0;
    for upper_agent_index in upper_row {
        let link = ForwardLink {
            upstream_index: *upper_agent_index,
            downstream_index: agent_index,
        };
        if links.contains(&link) {
            slot_total += slot;
            upstream_count += ONE_UPSTREAM_STEP;
        }
        slot += SLOT_STEP;
    }

    if upstream_count == 0.0 {
        return FIRST_SLOT;
    }
    slot_total / upstream_count
}

fn compare_ranked_steps(first: &RankedStep, second: &RankedStep) -> Ordering {
    let slot_order = first
        .average_upstream_slot
        .total_cmp(&second.average_upstream_slot);
    slot_order.then(first.agent_index.cmp(&second.agent_index))
}

fn place_rows(rows: &[Vec<usize>], agent_count: usize) -> Vec<CanvasPosition> {
    let mut widest_row_width = 0.0;
    for row in rows {
        widest_row_width = f64::max(widest_row_width, measure_row_width(row));
    }

    let mut positions = vec![CANVAS_ORIGIN; agent_count];
    let mut vertical = 0.0;
    for row in rows {
        let row_width = measure_row_width(row);
        let mut horizontal = (widest_row_width - row_width) / SIDES_OF_A_ROW;
        for agent_index in row {
            positions[*agent_index] = CanvasPosition {
                horizontal,
                vertical,
            };
            horizontal += COLUMN_PITCH;
        }
        vertical += ROW_PITCH;
    }
    positions
}

fn measure_row_width(row: &[usize]) -> f64 {
    let mut row_width = 0.0;
    for _ in row {
        row_width += COLUMN_PITCH;
    }
    row_width
}
