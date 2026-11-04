use chrono::DateTime;
use orchestration_api::work::{RunAssignment, RunEvent};
use orchestration_core::identifiers::WorkflowId;
use orchestration_core::run::{Run, StepStatus};
use orchestration_core::run_lifecycle::apply_step_status;
use orchestration_core::run_routing::advance_newly_done_steps;
use orchestration_core::step_results::record_step_result;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::{AgentConnection, Workflow};
use uuid::Uuid;

use crate::assignments::{assignment_for, task_for};
use crate::support::TestResult;
use crate::workflows::{
    WORKFLOW_NUMBER, WorkflowShape, agent_id, agent_name, build_workflow,
};

pub const DRAFT_INDEX: usize = 0;
pub const GATE_INDEX: usize = 1;
const SHIP_INDEX: usize = 2;
pub const STEP_COUNT: usize = 3;
pub const LOOP_OUTCOME: &str = "changes";
const FORWARD_OUTCOME: &str = "approved";
const LOOP_RUN_NUMBER: u128 = 0x9100;

pub fn gate_loop_workflow(round_limit: u32) -> Workflow {
    let shape = WorkflowShape {
        agent_count: STEP_COUNT,
        connections: vec![(DRAFT_INDEX, GATE_INDEX)],
        positions: vec![(0, 0), (0, 1), (0, 2)],
        failing_agents: Vec::new(),
    };
    let mut workflow = build_workflow(&shape);
    let gate_name = agent_name(GATE_INDEX);
    workflow.agents[GATE_INDEX].task =
        format!("{gate_name}\nplease-outcome-{LOOP_OUTCOME}");
    workflow.connections.push(AgentConnection {
        condition: Some(FORWARD_OUTCOME.to_owned()),
        ..AgentConnection::plain(agent_id(GATE_INDEX), agent_id(SHIP_INDEX))
    });
    workflow.connections.push(AgentConnection {
        condition: Some(LOOP_OUTCOME.to_owned()),
        round_limit: Some(round_limit),
        ..AgentConnection::plain(agent_id(GATE_INDEX), agent_id(DRAFT_INDEX))
    });
    workflow
}

pub fn gate_loop_assignment(round_limit: u32) -> TestResult<RunAssignment> {
    let doer = TaskDoer::Workflow {
        workflow_id: WorkflowId(Uuid::from_u128(WORKFLOW_NUMBER)),
    };
    let task = task_for(LOOP_RUN_NUMBER, "Review the change", doer);
    let workflow = gate_loop_workflow(round_limit);
    assignment_for(task, Some(workflow), Vec::new(), LOOP_RUN_NUMBER)
}

pub fn apply_step_events(
    run: &Run,
    workflow: &Workflow,
    events: &[RunEvent],
) -> TestResult<Run> {
    let mut applied = run.clone();
    for event in events {
        applied = apply_step_event(&applied, event)?;
    }
    let advanced = advance_newly_done_steps(
        run,
        &applied,
        workflow,
        DateTime::UNIX_EPOCH,
    )?;
    Ok(advanced)
}

pub fn finish_step(
    run: &Run,
    workflow: &Workflow,
    step_name: &str,
    result: &str,
    outcome: Option<&str>,
) -> TestResult<Run> {
    let events = [
        RunEvent::StepResultRecorded {
            step_name: step_name.to_owned(),
            result: result.to_owned(),
            outcome: outcome.map(str::to_owned),
        },
        RunEvent::StepStatusChanged {
            step_name: step_name.to_owned(),
            status: StepStatus::Done,
        },
    ];
    apply_step_events(run, workflow, &events)
}

fn apply_step_event(run: &Run, event: &RunEvent) -> TestResult<Run> {
    match event {
        RunEvent::StepResultRecorded {
            step_name,
            result,
            outcome,
        } => Ok(record_step_result(
            run,
            step_name,
            result,
            outcome.as_deref(),
        )?),
        RunEvent::StepStatusChanged { step_name, status } => {
            let at = DateTime::UNIX_EPOCH;
            Ok(apply_step_status(run, step_name, *status, at)?)
        }
        _ => Ok(run.clone()),
    }
}
