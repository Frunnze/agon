use std::sync::Arc;
use std::time::Duration;

use orchestration_api::work::RunAssignment;
use orchestration_core::identifiers::{RunId, WorkflowId};
use orchestration_core::run::StepStatus;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::Workflow;
use orchestration_core::workspace::Repository;
use orchestration_runner::runner::run_runner;
use tokio::runtime::Runtime;
use tokio::time::sleep;
use uuid::Uuid;

use crate::assignments::{assignment_for, rule_titled, task_for};
use crate::event_queries::step_statuses;
use crate::fake_agent::{AgentFolders, local_configuration};
use crate::fake_server::FakeServer;
use crate::support::TestResult;
use crate::workflows::{
    WORKFLOW_NUMBER, WorkflowShape, agent_name, build_workflow,
};

const RUN_NUMBER: u128 = 0xf000;
const RULE_NUMBER: u128 = 0xf100;
const SOURCE_INDEX: usize = 0;
const FINISH_POLL: Duration = Duration::from_millis(10);

#[derive(Debug)]
pub struct FanOutRun {
    pub folders: AgentFolders,
    pub reviewer_names: Vec<String>,
    pub server: Arc<FakeServer>,
    pub run_id: RunId,
}

fn fan_out_workflow(reviewer_instructions: &[String]) -> Workflow {
    let reviewer_count = reviewer_instructions.len();
    let mut connections = Vec::new();
    for reviewer_index in 1..=reviewer_count {
        connections.push((SOURCE_INDEX, reviewer_index));
    }
    let shape = WorkflowShape {
        agent_count: reviewer_count + 1,
        connections,
        positions: Vec::new(),
        failing_agents: Vec::new(),
    };

    let mut workflow = build_workflow(&shape);
    let reviewers = workflow.agents.iter_mut().skip(1);
    for (reviewer, instruction) in reviewers.zip(reviewer_instructions) {
        reviewer.task = format!("{}\n{instruction}", reviewer.name);
    }
    workflow
}

pub fn queue_reviewers(
    reviewer_instructions: &[String],
    repositories: Vec<Repository>,
) -> TestResult<Vec<RunAssignment>> {
    let doer = TaskDoer::Workflow {
        workflow_id: WorkflowId(Uuid::from_u128(WORKFLOW_NUMBER)),
    };
    let task = task_for(RUN_NUMBER, "Review the change", doer);
    let workflow = fan_out_workflow(reviewer_instructions);
    let mut base =
        assignment_for(task, Some(workflow), repositories, RUN_NUMBER)?;
    base.rules = vec![rule_titled(RULE_NUMBER, "Review calmly", true)];
    let source_name = agent_name(SOURCE_INDEX);
    for step in &mut base.run.steps {
        if step.name == source_name {
            step.status = StepStatus::Done;
            step.result = Some(format!("finished {source_name}"));
        }
    }

    let mut assignments = Vec::new();
    for reviewer_index in 1..=reviewer_instructions.len() {
        assignments.push(RunAssignment {
            step_name: agent_name(reviewer_index),
            ..base.clone()
        });
    }
    Ok(assignments)
}

pub fn statuses_of_step(
    run_statuses: &[(String, StepStatus)],
    step_name: &str,
) -> Vec<StepStatus> {
    let mut statuses = Vec::new();
    for (name, status) in run_statuses {
        if name == step_name {
            statuses.push(*status);
        }
    }
    statuses
}

fn has_step_ended(statuses: &[(String, StepStatus)], step_name: &str) -> bool {
    for status in statuses_of_step(statuses, step_name) {
        if matches!(status, StepStatus::Done | StepStatus::Failed) {
            return true;
        }
    }
    false
}

fn has_every_step_ended(
    server: &FakeServer,
    run_id: RunId,
    step_names: &[String],
) -> bool {
    let statuses = step_statuses(&server.events_of(run_id));
    for step_name in step_names {
        if !has_step_ended(&statuses, step_name) {
            return false;
        }
    }
    true
}

pub fn run_fan_out(
    folders: AgentFolders,
    assignments: Vec<RunAssignment>,
) -> TestResult<FanOutRun> {
    let capacity = u32::try_from(assignments.len())?;
    let configuration = local_configuration(&folders, capacity)?;
    let run_id = RunId(Uuid::from_u128(RUN_NUMBER));
    let reviewer_names: Vec<String> = assignments
        .iter()
        .map(|assignment| assignment.step_name.clone())
        .collect();
    let server = Arc::new(FakeServer::with_queue(assignments));
    let watched_server = Arc::clone(&server);
    let watched_names = reviewer_names.clone();
    let shutdown = async move {
        while !has_every_step_ended(&watched_server, run_id, &watched_names) {
            sleep(FINISH_POLL).await;
        }
    };

    let runtime = Runtime::new()?;
    let runner_server = Arc::clone(&server);
    runtime.block_on(run_runner(runner_server, &configuration, shutdown))?;
    Ok(FanOutRun {
        folders,
        reviewer_names,
        server,
        run_id,
    })
}
