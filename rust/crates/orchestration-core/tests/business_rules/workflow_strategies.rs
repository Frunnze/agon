use std::ops::RangeInclusive;

use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{WorkflowAgentId, WorkflowId};
use orchestration_core::run::{RunStep, StepStatus};
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{
    AgentConnection, CanvasPosition, StepKind, Workflow, WorkflowAgent,
};
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::{agent_kind, runner_target};

const MAXIMUM_AGENTS: usize = 6;
const MAXIMUM_CONNECTIONS: usize = 10;
const DISTINCT_ARBITRARY_AGENT_IDS: u128 = 5;
const MAXIMUM_STEPS: usize = 6;
const LARGEST_COORDINATE: f64 = 4.0;

pub fn workflow_identifier() -> WorkflowId {
    WorkflowId(Uuid::from_u128(u128::MAX))
}

pub fn agent_identifier(number: u128) -> WorkflowAgentId {
    WorkflowAgentId(Uuid::from_u128(number))
}

fn canvas_position() -> impl Strategy<Value = CanvasPosition> {
    let coordinate = (0.0..LARGEST_COORDINATE).prop_map(f64::floor);
    (coordinate.clone(), coordinate).prop_map(|(horizontal, vertical)| {
        CanvasPosition {
            horizontal,
            vertical,
        }
    })
}

fn workflow_agent(
    id: WorkflowAgentId,
    name: String,
    position: CanvasPosition,
) -> WorkflowAgent {
    WorkflowAgent {
        id,
        name,
        kind: None,
        task: String::new(),
        runs_on: RunnerTarget::AnyFreeRunner,
        skills: Vec::new(),
        uses_automatic_skills: false,
        approval_policy: ApprovalPolicy::NeverAsk,
        position,
        step_kind: StepKind::Agent,
    }
}

pub fn workflow_from_parts(
    agents: Vec<WorkflowAgent>,
    connections: Vec<AgentConnection>,
) -> Workflow {
    Workflow {
        id: workflow_identifier(),
        name: "release".to_owned(),
        availability: WorkspaceScope::AllWorkspaces,
        agents,
        connections,
        signature: None,
    }
}

pub fn acyclic_workflow_with_agent_counts(
    agent_counts: RangeInclusive<usize>,
) -> impl Strategy<Value = Workflow> {
    agent_counts
        .prop_flat_map(|agent_count| {
            (
                vec(canvas_position(), agent_count),
                vec((0..agent_count, 0..agent_count), 0..MAXIMUM_CONNECTIONS),
            )
        })
        .prop_map(|(positions, index_pairs)| {
            let mut agents = Vec::new();
            for (number, position) in (0u128..).zip(positions) {
                let name = format!("agent-{number}");
                let id = agent_identifier(number);
                agents.push(workflow_agent(id, name, position));
            }
            let mut connections = Vec::new();
            for (first, second) in index_pairs {
                if first < second {
                    connections.push(AgentConnection::plain(
                        agents[first].id,
                        agents[second].id,
                    ));
                }
            }
            workflow_from_parts(agents, connections)
        })
}

pub fn acyclic_workflow() -> impl Strategy<Value = Workflow> {
    acyclic_workflow_with_agent_counts(1..=MAXIMUM_AGENTS)
}

pub fn workflow_with_cycle() -> impl Strategy<Value = Workflow> {
    let smallest_cycle_agent_count = 2;
    acyclic_workflow_with_agent_counts(
        smallest_cycle_agent_count..=MAXIMUM_AGENTS,
    )
    .prop_map(|workflow| {
        let first_id = workflow.agents[0].id;
        let last_id = workflow.agents[workflow.agents.len() - 1].id;
        let mut connections = workflow.connections.clone();
        connections.push(AgentConnection::plain(first_id, last_id));
        connections.push(AgentConnection::plain(last_id, first_id));
        workflow_from_parts(workflow.agents.clone(), connections)
    })
}

pub fn arbitrary_workflow() -> impl Strategy<Value = Workflow> {
    let agent = (
        0..DISTINCT_ARBITRARY_AGENT_IDS,
        "[a-c]{0,2}",
        canvas_position(),
        option::of(agent_kind()),
        any::<String>(),
        runner_target(),
    )
        .prop_map(|(number, name, position, kind, task, runs_on)| {
            WorkflowAgent {
                kind,
                task,
                runs_on,
                ..workflow_agent(agent_identifier(number), name, position)
            }
        });
    let connection = (
        0..DISTINCT_ARBITRARY_AGENT_IDS,
        0..DISTINCT_ARBITRARY_AGENT_IDS,
    )
        .prop_map(|(from, to)| {
            AgentConnection::plain(
                agent_identifier(from),
                agent_identifier(to),
            )
        });
    (
        vec(agent, 0..MAXIMUM_AGENTS),
        vec(connection, 0..MAXIMUM_CONNECTIONS),
    )
        .prop_map(|(agents, connections)| {
            workflow_from_parts(agents, connections)
        })
}

pub fn step_status() -> impl Strategy<Value = StepStatus> {
    prop_oneof![
        Just(StepStatus::Waiting),
        Just(StepStatus::Running),
        Just(StepStatus::WaitingForApproval),
        Just(StepStatus::WaitingForPerson),
        Just(StepStatus::Done),
        Just(StepStatus::Failed),
        Just(StepStatus::Skipped),
    ]
}

pub fn run_steps() -> impl Strategy<Value = Vec<RunStep>> {
    vec(step_status(), 0..MAXIMUM_STEPS).prop_map(|statuses| {
        let mut steps = Vec::new();
        for (index, status) in statuses.into_iter().enumerate() {
            steps.push(RunStep {
                name: format!("step-{index}"),
                agent_id: None,
                runner: None,
                status,
                started_at: None,
                finished_at: None,
                result: None,
                outcome: None,
                loop_source: None,
                earlier_rounds: Vec::new(),
            });
        }
        steps
    })
}
