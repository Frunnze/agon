use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{WorkflowAgentId, WorkflowId};
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{
    AgentConnection, AgentKind, CanvasPosition, StepKind, Workflow,
    WorkflowAgent,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

pub const WORKFLOW_NUMBER: u128 = 0xc0c0;
const AGENT_NUMBER_OFFSET: u128 = 0xd000;
const MAXIMUM_AGENTS: usize = 4;
const CANVAS_CELLS: u8 = 4;
const FAILURE_INSTRUCTION: &str = "please-fail";

#[derive(Clone, Debug)]
pub struct WorkflowShape {
    pub agent_count: usize,
    pub connections: Vec<(usize, usize)>,
    pub positions: Vec<(u8, u8)>,
    pub failing_agents: Vec<bool>,
}

pub fn agent_name(index: usize) -> String {
    format!("step-{index}")
}

pub fn agent_id(index: usize) -> WorkflowAgentId {
    let offset = u128::try_from(index).unwrap_or_default();
    WorkflowAgentId(Uuid::from_u128(AGENT_NUMBER_OFFSET + offset))
}

pub fn any_workflow_shape() -> impl Strategy<Value = WorkflowShape> {
    (1..=MAXIMUM_AGENTS).prop_flat_map(|agent_count| {
        let pair_count = agent_count * (agent_count - 1) / 2;
        (
            vec(any::<bool>(), pair_count),
            vec((0..CANVAS_CELLS, 0..CANVAS_CELLS), agent_count),
            vec(prop::bool::weighted(0.25), agent_count),
        )
            .prop_map(
                move |(chosen_pairs, positions, failing_agents)| {
                    WorkflowShape {
                        agent_count,
                        connections: choose_connections(
                            agent_count,
                            &chosen_pairs,
                        ),
                        positions,
                        failing_agents,
                    }
                },
            )
    })
}

fn choose_connections(
    agent_count: usize,
    chosen_pairs: &[bool],
) -> Vec<(usize, usize)> {
    let mut connections = Vec::new();
    let mut pair_index = 0;
    for from in 0..agent_count {
        for to in from + 1..agent_count {
            if chosen_pairs.get(pair_index) == Some(&true) {
                connections.push((from, to));
            }
            pair_index += 1;
        }
    }
    connections
}

pub fn build_workflow(shape: &WorkflowShape) -> Workflow {
    let mut agents = Vec::new();
    for index in 0..shape.agent_count {
        let (horizontal, vertical) =
            shape.positions.get(index).copied().unwrap_or_default();
        let is_failing = shape.failing_agents.get(index) == Some(&true);
        agents.push(WorkflowAgent {
            id: agent_id(index),
            name: agent_name(index),
            kind: Some(AgentKind::ClaudeCode),
            task: agent_task(index, is_failing),
            runs_on: RunnerTarget::AnyFreeRunner,
            skills: Vec::new(),
            uses_automatic_skills: false,
            approval_policy: Some(ApprovalPolicy::NeverAsk),
            position: CanvasPosition {
                horizontal: f64::from(horizontal),
                vertical: f64::from(vertical),
            },
            step_kind: StepKind::Agent,
        });
    }

    let mut connections = Vec::new();
    for (from, to) in &shape.connections {
        connections
            .push(AgentConnection::plain(agent_id(*from), agent_id(*to)));
    }
    Workflow {
        id: WorkflowId(Uuid::from_u128(WORKFLOW_NUMBER)),
        name: "generated".to_string(),
        availability: WorkspaceScope::AllWorkspaces,
        agents,
        connections,
        signature: None,
    }
}

fn agent_task(index: usize, is_failing: bool) -> String {
    let name = agent_name(index);
    if is_failing {
        return format!("{name}\n{FAILURE_INSTRUCTION}");
    }
    name
}
