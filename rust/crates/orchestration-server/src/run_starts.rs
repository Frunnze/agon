use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use orchestration_core::identifiers::{
    DeviceId, RunId, TaskId, generate_uuid,
};
use orchestration_core::run::{Run, RunStatus};
use orchestration_core::run_lifecycle::create_run;
use orchestration_core::task::{Task, TaskDoer, TaskStatus};
use orchestration_core::workflow::Workflow;
use orchestration_core::workspace::Project;

use crate::error::ServerError;
use crate::stored_state::{RunRecord, StoredState};
use crate::task_places::find_task_project;
use crate::workflows::signed_workflow;

const FIRST_RUN_NUMBER: u32 = 1;
const DETAIL_SEPARATOR: &str = " · ";
const ADDRESS_PART_SEPARATOR: char = '/';

pub fn start_run(
    state: &mut StoredState,
    task_id: TaskId,
    started_by: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Run, ServerError> {
    let task = state
        .tasks
        .get(&task_id)
        .ok_or(ServerError::NotFound("the task"))?;
    let workflow = match &task.doer {
        TaskDoer::OneAgent { .. } => None,
        TaskDoer::Workflow { workflow_id } => {
            Some(signed_workflow(state, *workflow_id)?)
        }
    };
    let number = next_run_number(state, task_id);
    let run = create_run(
        task,
        workflow,
        number,
        RunId(generate_uuid()),
        started_by.clone(),
        now,
    )?;

    let record = RunRecord {
        run: run.clone(),
        pinned_steps: BTreeMap::new(),
        follow_ups: BTreeMap::new(),
    };
    state.runs.insert(run.id, record);
    sync_task_status(state, task_id, run.status);
    Ok(run)
}

pub fn sync_task_status(
    state: &mut StoredState,
    task_id: TaskId,
    run_status: RunStatus,
) {
    if let Some(task) = state.tasks.get_mut(&task_id) {
        task.status = task_status_for(run_status);
    }
}

pub fn run_workflow<'state>(
    state: &'state StoredState,
    task: &Task,
) -> Option<&'state Workflow> {
    let TaskDoer::Workflow { workflow_id } = &task.doer else {
        return None;
    };
    state
        .workflows
        .get(workflow_id)
        .and_then(|record| record.last_signed.as_ref())
}

pub fn describe_run_detail(state: &StoredState, run: &Run) -> String {
    let project = find_run_project(state, run);
    let place = project.map_or_else(String::new, describe_project_place);
    format!("{}{DETAIL_SEPARATOR}{place}", describe_run(state, run))
}

fn find_run_project<'state>(
    state: &'state StoredState,
    run: &Run,
) -> Option<&'state Project> {
    let task = state.tasks.get(&run.task_id)?;
    find_task_project(state, task).ok()?
}

fn describe_project_place(project: &Project) -> String {
    let Some(repository) = project.repositories.first() else {
        return project.name.clone();
    };
    let address = repository.address.as_str();
    let owner_and_name = address
        .split_once(ADDRESS_PART_SEPARATOR)
        .map_or(address, |(_host, rest)| rest);
    owner_and_name.to_owned()
}

pub fn describe_run(state: &StoredState, run: &Run) -> String {
    let task = state.tasks.get(&run.task_id);
    let workflow = task.and_then(|task| run_workflow(state, task));
    let name = match (workflow, task) {
        (Some(workflow), _) => workflow.name.clone(),
        (None, Some(task)) => task.title.clone(),
        (None, None) => run.id.0.to_string(),
    };
    format!("{name} #{}", run.number)
}

fn next_run_number(state: &StoredState, task_id: TaskId) -> u32 {
    let latest_number = state
        .runs
        .values()
        .filter(|record| record.run.task_id == task_id)
        .map(|record| record.run.number)
        .max();
    latest_number.map_or(FIRST_RUN_NUMBER, |number| {
        number.saturating_add(FIRST_RUN_NUMBER)
    })
}

fn task_status_for(run_status: RunStatus) -> TaskStatus {
    match run_status {
        RunStatus::Queued | RunStatus::Running => TaskStatus::Running,
        RunStatus::WaitingForApproval => TaskStatus::WaitingForApproval,
        RunStatus::Failed => TaskStatus::Failed,
        RunStatus::Cancelled => TaskStatus::ToDo,
        RunStatus::Done => TaskStatus::Done,
    }
}
