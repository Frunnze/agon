use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::validate_workflow;
use proptest::prelude::*;
use serde_json::{Value, json};

pub const DRAFT_PROBLEM_START: &str =
    "the drafting agent did not answer with a workflow: ";
pub const ROW_PITCH: f64 = 152.0;
const MOST_STEPS: usize = 6;
const STEP_ID_PREFIX: &str = "00000000-0000-0000-0000-0000000001";
const STEP_NAME_PREFIX: &str = "step-";
const POSITION_LIMIT: f64 = 100_000.0;

type StepLink = (usize, usize);

#[derive(Clone, Debug)]
pub struct DraftedGraph {
    pub step_count: usize,
    pub links: Vec<StepLink>,
    pub drafted_positions: Vec<(f64, f64)>,
}

fn list_forward_pairs(step_count: usize) -> Vec<StepLink> {
    let mut pairs = Vec::new();
    for from in 0..step_count {
        for to in (from + 1)..step_count {
            pairs.push((from, to));
        }
    }
    pairs
}

fn pick_links(pairs: &[StepLink], choices: &[bool]) -> Vec<StepLink> {
    let mut links = Vec::new();
    for (pair, is_chosen) in pairs.iter().zip(choices) {
        if *is_chosen {
            links.push(*pair);
        }
    }
    links
}

fn position_strategy() -> impl Strategy<Value = (f64, f64)> {
    let coordinate = -POSITION_LIMIT..POSITION_LIMIT;
    (coordinate.clone(), coordinate)
}

pub fn acyclic_graph_strategy() -> impl Strategy<Value = DraftedGraph> {
    (1..=MOST_STEPS).prop_flat_map(|step_count| {
        let pairs = list_forward_pairs(step_count);
        let choices = proptest::collection::vec(any::<bool>(), pairs.len());
        let positions =
            proptest::collection::vec(position_strategy(), step_count);
        (choices, positions).prop_map(move |(choices, drafted_positions)| {
            DraftedGraph {
                step_count,
                links: pick_links(&pairs, &choices),
                drafted_positions,
            }
        })
    })
}

fn close_cycle(
    graph: DraftedGraph,
    first: usize,
    last: usize,
) -> DraftedGraph {
    let mut links = graph.links;
    for from in first..last {
        let chain_link = (from, from + 1);
        if !links.contains(&chain_link) {
            links.push(chain_link);
        }
    }
    links.push((last, first));
    DraftedGraph { links, ..graph }
}

pub fn cyclic_graph_strategy() -> impl Strategy<Value = DraftedGraph> {
    acyclic_graph_strategy().prop_flat_map(|graph| {
        let step_count = graph.step_count;
        (Just(graph), 0..step_count, 0..step_count).prop_map(
            |(graph, one_end, other_end)| {
                let first = one_end.min(other_end);
                let last = one_end.max(other_end);
                close_cycle(graph, first, last)
            },
        )
    })
}

pub fn any_graph_strategy() -> impl Strategy<Value = DraftedGraph> {
    prop_oneof![acyclic_graph_strategy(), cyclic_graph_strategy()]
}

pub fn step_id(index: usize) -> String {
    format!("{STEP_ID_PREFIX}{index:02}")
}

fn step_json(index: usize, position: (f64, f64)) -> Value {
    json!({
        "id": step_id(index),
        "name": format!("{STEP_NAME_PREFIX}{index}"),
        "kind": "claude_code",
        "task": format!("Do part {index}"),
        "runs_on": { "kind": "any_free_runner" },
        "skills": [],
        "uses_automatic_skills": false,
        "approval_policy": "never_ask",
        "position": { "horizontal": position.0, "vertical": position.1 },
    })
}

pub fn drafted_workflow_value(
    workflow_id: &str,
    name: &str,
    graph: &DraftedGraph,
) -> Value {
    let mut steps = Vec::new();
    for (index, position) in graph.drafted_positions.iter().enumerate() {
        steps.push(step_json(index, *position));
    }
    let mut connections = Vec::new();
    for (from, to) in &graph.links {
        connections
            .push(json!({ "from": step_id(*from), "to": step_id(*to) }));
    }
    json!({
        "id": workflow_id,
        "name": name,
        "availability": { "kind": "all_workspaces" },
        "agents": steps,
        "connections": connections,
        "signature": null,
    })
}

pub fn decode_workflow(value: &Value) -> Result<Workflow, String> {
    serde_json::from_value(value.clone()).map_err(|error| error.to_string())
}

pub fn expected_draft_problem(drafted: &Workflow) -> Option<String> {
    let problem = validate_workflow(drafted).err()?;
    Some(format!("{DRAFT_PROBLEM_START}{problem}"))
}

pub fn has_step_in_top_row(workflow: &Workflow) -> bool {
    workflow
        .agents
        .iter()
        .any(|agent| agent.position.vertical == 0.0)
}

pub fn lowest_row_vertical(workflow: &Workflow) -> f64 {
    let mut lowest = 0.0_f64;
    for agent in &workflow.agents {
        lowest = lowest.max(agent.position.vertical);
    }
    lowest
}

pub fn row_limit(step_count: usize) -> f64 {
    let mut limit = 0.0_f64;
    for _row_below_top in 1..step_count {
        limit += ROW_PITCH;
    }
    limit
}
