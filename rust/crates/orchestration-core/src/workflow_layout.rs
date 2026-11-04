use crate::workflow::{CanvasPosition, Workflow, WorkflowAgent};
use crate::workflow_columns::place_steps_in_columns;
use crate::workflow_fork_lanes::list_fork_lanes;
use crate::workflow_layers::{assign_layers, count_rows, list_forward_links};

const STEP_WIDTH: f64 = 160.0;
const STEP_HEIGHT: f64 = 88.0;
const GAP_BETWEEN_COLUMNS: f64 = 48.0;
const GAP_BETWEEN_ROWS: f64 = 64.0;
const COLUMN_PITCH: f64 = STEP_WIDTH + GAP_BETWEEN_COLUMNS;
const ROW_PITCH: f64 = STEP_HEIGHT + GAP_BETWEEN_ROWS;
const TOP_ROW_VERTICAL: f64 = 0.0;

#[must_use]
pub fn lay_out_workflow(workflow: &Workflow) -> Workflow {
    let links = list_forward_links(workflow);
    let layers = assign_layers(workflow.agents.len(), &links);
    let lanes = list_fork_lanes(&links, &layers);
    let columns = place_steps_in_columns(&layers, &links, &lanes);
    let row_verticals = list_row_verticals(count_rows(&layers));

    let mut agents = Vec::new();
    for (agent_index, agent) in workflow.agents.iter().enumerate() {
        let position = CanvasPosition {
            horizontal: columns[agent_index] * COLUMN_PITCH,
            vertical: row_verticals[layers[agent_index]],
        };
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

fn list_row_verticals(row_count: usize) -> Vec<f64> {
    let mut row_verticals = Vec::new();
    let mut vertical = TOP_ROW_VERTICAL;
    for _ in 0..row_count {
        row_verticals.push(vertical);
        vertical += ROW_PITCH;
    }
    row_verticals
}
