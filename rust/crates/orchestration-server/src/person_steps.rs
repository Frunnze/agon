use axum::Json;
use axum::extract::State;
use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::{AnswerPersonStepRequest, OpenPersonStep};
use orchestration_core::identifiers::{DeviceId, RunId};
use orchestration_core::run::{Run, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{RunProblem, is_run_finished};
use orchestration_core::run_routing::advance_after_step;
use orchestration_core::step_outcomes::{list_step_choices, match_choice};
use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::find_agent_by_id;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::memberships::is_workspace_member;
use crate::run_starts::{
    describe_run, describe_run_detail, find_run_workflow, sync_task_status,
};
use crate::runs::find_run;
use crate::server::SharedServer;
use crate::stored_state::{RunRecord, StoredState};
use crate::task_places::find_task_workspace;
use crate::tasks::require_task_access;

const NOT_WAITING: &str = "the step is not waiting for a person";
const NO_WORKFLOW: &str = "the run has no signed workflow";

pub async fn list_person_steps(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Vec<OpenPersonStep>>, ServerError> {
    request.caller.require_client()?;
    let caller_id = &request.caller.device_id;
    let open_steps =
        server.read(|state| Ok(list_open_steps(state, caller_id)))?;
    Ok(Json(open_steps))
}

pub async fn answer_person_step(
    State(server): State<SharedServer>,
    PathValue((run_uuid, step_name)): PathValue<(Uuid, String)>,
    request: SignedRequest,
) -> Result<Json<Run>, ServerError> {
    request.caller.require_client()?;
    let answer_request: AnswerPersonStepRequest =
        parse_json_body(&request.body)?;
    if answer_request.answer.trim().is_empty() {
        return Err(ServerError::Invalid(
            "an answer cannot be empty".to_owned(),
        ));
    }
    let caller_id = &request.caller.device_id;
    let answer = PersonAnswer {
        run_id: RunId(run_uuid),
        step_name: &step_name,
        request: &answer_request,
    };
    let run = server.apply(caller_id, |state, now| {
        record_person_answer(state, &answer, caller_id, now)
    })?;
    Ok(Json(run))
}

struct PersonAnswer<'answer> {
    run_id: RunId,
    step_name: &'answer str,
    request: &'answer AnswerPersonStepRequest,
}

fn list_open_steps(
    state: &StoredState,
    caller_id: &DeviceId,
) -> Vec<OpenPersonStep> {
    let mut open_steps = Vec::new();
    for record in state.runs.values() {
        let run = &record.run;
        if is_run_finished(run.status) {
            continue;
        }
        let Some(task) = state.tasks.get(&run.task_id) else {
            continue;
        };
        let Ok(workspace_id) = find_task_workspace(state, task) else {
            continue;
        };
        let Some(workflow) = find_run_workflow(state, record) else {
            continue;
        };
        if !is_workspace_member(state, caller_id, workspace_id) {
            continue;
        }
        for step in &run.steps {
            if step.status != StepStatus::WaitingForPerson {
                continue;
            }
            let Some(agent_id) = step.agent_id else {
                continue;
            };
            let Some(agent) = find_agent_by_id(workflow, agent_id) else {
                continue;
            };
            open_steps.push(OpenPersonStep {
                run_id: run.id,
                task_id: run.task_id,
                workspace_id,
                step_name: step.name.clone(),
                question: agent.task.clone(),
                choices: list_step_choices(workflow, agent_id),
                asked_at: step.started_at,
            });
        }
    }
    open_steps.sort_by_key(|open_step| open_step.asked_at);
    open_steps
}

fn record_person_answer(
    state: &mut StoredState,
    answer: &PersonAnswer<'_>,
    caller_id: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Change<Run>, ServerError> {
    let record = find_run(state, answer.run_id)?;
    let task = state
        .tasks
        .get(&record.run.task_id)
        .ok_or(ServerError::NotFound("the task"))?;
    require_task_access(state, caller_id, task)?;
    if is_run_finished(record.run.status) {
        return Err(RunProblem::RunAlreadyFinished.into());
    }
    let workflow = find_run_workflow(state, record)
        .ok_or_else(|| ServerError::Conflict(NO_WORKFLOW.to_owned()))?;
    let step = record
        .run
        .steps
        .iter()
        .find(|step| step.name == answer.step_name)
        .ok_or(ServerError::NotFound("the step"))?;
    if step.status != StepStatus::WaitingForPerson {
        return Err(ServerError::Conflict(NOT_WAITING.to_owned()));
    }

    let outcome = choose_outcome(workflow, step, answer.request)?;
    let answered = answer_step(
        &record.run,
        step,
        answer.request,
        outcome.as_deref(),
        now,
    );
    let advanced =
        advance_after_step(&answered, workflow, answer.step_name, now);
    let changed = RunRecord {
        run: advanced,
        ..record.clone()
    };
    let run = changed.run.clone();
    state.runs.insert(run.id, changed);
    sync_task_status(state, run.task_id, run.status);

    let event_text = format!(
        "Answered step {} in {}",
        answer.step_name,
        describe_run(state, &run)
    );
    let detail = describe_run_detail(state, &run);
    let topic = ChangeTopic::Run { run_id: run.id };
    Ok(Change::recorded(run, topic, event_text).with_detail(detail))
}

fn choose_outcome(
    workflow: &Workflow,
    step: &RunStep,
    request: &AnswerPersonStepRequest,
) -> Result<Option<String>, ServerError> {
    let Some(agent_id) = step.agent_id else {
        return Ok(None);
    };
    let choices = list_step_choices(workflow, agent_id);
    if choices.is_empty() {
        return Ok(None);
    }
    let chosen_text = request.choice.as_ref().unwrap_or(&request.answer);
    match match_choice(chosen_text, &choices) {
        Some(outcome) => Ok(Some(outcome)),
        None => Err(ServerError::UnmatchedAnswer(choices)),
    }
}

fn answer_step(
    run: &Run,
    answered_step: &RunStep,
    request: &AnswerPersonStepRequest,
    outcome: Option<&str>,
    now: DateTime<Utc>,
) -> Run {
    let mut steps = Vec::new();
    for step in &run.steps {
        if step.name != answered_step.name {
            steps.push(step.clone());
            continue;
        }
        steps.push(RunStep {
            status: StepStatus::Done,
            finished_at: Some(now),
            result: Some(request.answer.clone()),
            outcome: outcome.map(str::to_owned),
            ..step.clone()
        });
    }
    Run {
        steps,
        ..run.clone()
    }
}
