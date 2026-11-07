use orchestration_core::workflow::{CanvasPosition, StepKind, Workflow};
use serde::Deserialize;

use crate::routing_fixtures::{connect, routing_agent};
use crate::workflow_strategies::workflow_from_parts;

const TREE_LAYOUT_CASES: &str = include_str!("tree_layout_cases.json");

#[derive(Debug, Deserialize)]
struct RecordedTree {
    agents: Vec<(u128, f64, f64)>,
    connections: Vec<(u128, u128, Option<String>)>,
}

pub struct TreeCase {
    pub workflow: Workflow,
    pub positions: Vec<CanvasPosition>,
}

pub fn read_tree_cases() -> Result<Vec<TreeCase>, serde_json::Error> {
    let recorded_trees: Vec<RecordedTree> =
        serde_json::from_str(TREE_LAYOUT_CASES)?;
    let mut tree_cases = Vec::new();
    for recorded_tree in recorded_trees {
        tree_cases.push(build_tree_case(&recorded_tree));
    }
    Ok(tree_cases)
}

fn build_tree_case(recorded_tree: &RecordedTree) -> TreeCase {
    let mut agents = Vec::new();
    let mut positions = Vec::new();
    for (number, horizontal, vertical) in &recorded_tree.agents {
        agents.push(routing_agent(*number, StepKind::Agent));
        positions.push(CanvasPosition {
            horizontal: *horizontal,
            vertical: *vertical,
        });
    }
    let mut connections = Vec::new();
    for (from, to, condition) in &recorded_tree.connections {
        connections.push(connect(*from, *to, condition.as_deref(), None));
    }
    TreeCase {
        workflow: workflow_from_parts(agents, connections),
        positions,
    }
}
