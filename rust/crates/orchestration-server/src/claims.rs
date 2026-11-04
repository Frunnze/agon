use axum::Json;
use axum::extract::State;
use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::{ClaimResponse, FollowUp, RunAssignment};
use orchestration_core::agent_place::can_take_place;
use orchestration_core::device::{Runner, RunnerTarget};
use orchestration_core::identifiers::{DeviceId, RunId, WorkspaceId};
use orchestration_core::library::{Rule, Skill};
use orchestration_core::local_folders::find_folder_device;
use orchestration_core::run::{Run, RunStatus, RunStep};
use orchestration_core::run_routing::is_step_claimable;
use orchestration_core::runner_matching::choose_runner;
use orchestration_core::scope_rules::applies_to;
use orchestration_core::task::Task;
use orchestration_core::workflow::{Workflow, WorkflowAgent};
use orchestration_core::workspace::{Project, Repository};

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::name_device;
use crate::error::ServerError;
use crate::memberships::is_workspace_member;
use crate::request_ledger::Presence;
use crate::run_starts::{describe_run, describe_run_detail, run_workflow};
use crate::runners::present_runners;
use crate::server::SharedServer;
use crate::stored_state::{RunRecord, StoredState};
use crate::task_places::{find_task_project, find_task_workspace};
use crate::workspace_approvals::find_workspace_approval_policy;
use crate::workspace_protected_files::find_workspace_protected_files;

pub async fn claim_next_run(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<ClaimResponse>, ServerError> {
    request.caller.require_runner()?;
    let presence = server.presence_snapshot()?;
    let runner_id = &request.caller.device_id;
    let response = server.apply(runner_id, |state, now| {
        give_next_step(state, &presence, runner_id, now)
    })?;
    Ok(Json(response))
}

fn give_next_step(
    state: &mut StoredState,
    presence: &Presence,
    runner_id: &DeviceId,
    now: DateTime<Utc>,
) -> Result<Change<ClaimResponse>, ServerError> {
    let runners = present_runners(state, presence, now);
    for run_id in queued_run_ids(state) {
        let step_name =
            find_claimable_step(state, run_id, &runners, runner_id);
        if let Some(step_name) = step_name {
            let assignment =
                assign_step(state, run_id, &step_name, runner_id)?;
            let event_text = format!(
                "Gave step {step_name} of {} to {}",
                describe_run(state, &assignment.run),
                name_device(state, runner_id)
            );
            let detail = describe_run_detail(state, &assignment.run);
            let response = ClaimResponse {
                assignment: Some(assignment),
            };
            let topic = ChangeTopic::Run { run_id };
            let change = Change::recorded(response, topic, event_text);
            return Ok(change.with_detail(detail));
        }
    }
    Ok(Change::unchanged(ClaimResponse { assignment: None }))
}

fn queued_run_ids(state: &StoredState) -> Vec<RunId> {
    let mut waiting_runs: Vec<&Run> = state
        .runs
        .values()
        .map(|record| &record.run)
        .filter(|run| is_waiting_for_runners(run.status))
        .collect();
    waiting_runs.sort_by_key(|run| (run.started_at, run.id));
    waiting_runs.iter().map(|run| run.id).collect()
}

fn is_waiting_for_runners(status: RunStatus) -> bool {
    matches!(
        status,
        RunStatus::Queued | RunStatus::Running | RunStatus::WaitingForApproval
    )
}

fn find_claimable_step(
    state: &StoredState,
    run_id: RunId,
    runners: &[Runner],
    runner_id: &DeviceId,
) -> Option<String> {
    let record = state.runs.get(&run_id)?;
    let task = state.tasks.get(&record.run.task_id)?;
    let workspace_id = find_task_workspace(state, task).ok()?;
    let project = find_task_project(state, task).ok()?;
    let repositories: &[Repository] = match project {
        Some(project) => &project.repositories,
        None => &[],
    };
    let workflow = run_workflow(state, task);
    let eligible_runners =
        eligible_runners(state, runners, task, workspace_id, repositories);

    for step in &record.run.steps {
        if !is_step_claimable(&record.run, step, workflow) {
            continue;
        }
        let target = target_for_step(record, step, task, workflow);
        let chosen_runner = choose_runner(&target, &eligible_runners);
        if chosen_runner.as_ref() == Some(runner_id) {
            return Some(step.name.clone());
        }
    }
    None
}

fn eligible_runners(
    state: &StoredState,
    runners: &[Runner],
    task: &Task,
    workspace_id: WorkspaceId,
    repositories: &[Repository],
) -> Vec<Runner> {
    let Ok(folder_device) = find_folder_device(repositories) else {
        return Vec::new();
    };
    let mut eligible = Vec::new();
    for runner in runners {
        let runner_id = &runner.device_id;
        let is_member = is_workspace_member(state, runner_id, workspace_id);
        let holds_folders = folder_device
            .as_ref()
            .is_none_or(|folder_device_id| folder_device_id == runner_id);
        let offers_place = can_take_place(&runner.offers, task.agent_place);
        if is_member && holds_folders && offers_place {
            eligible.push(runner.clone());
        }
    }
    eligible
}

pub fn target_for_step(
    record: &RunRecord,
    step: &RunStep,
    task: &Task,
    workflow: Option<&Workflow>,
) -> RunnerTarget {
    if let Some(pinned_runner) = record.pinned_steps.get(&step.name) {
        return RunnerTarget::SpecificRunner {
            device_id: pinned_runner.clone(),
        };
    }
    let agent = workflow.and_then(|workflow| find_agent(workflow, step));
    agent.map_or_else(|| task.runs_on.clone(), |agent| agent.runs_on.clone())
}

fn find_agent<'workflow>(
    workflow: &'workflow Workflow,
    step: &RunStep,
) -> Option<&'workflow WorkflowAgent> {
    workflow
        .agents
        .iter()
        .find(|agent| Some(agent.id) == step.agent_id)
}

fn assign_step(
    state: &mut StoredState,
    run_id: RunId,
    step_name: &str,
    runner_id: &DeviceId,
) -> Result<RunAssignment, ServerError> {
    let record = state
        .runs
        .get_mut(&run_id)
        .ok_or(ServerError::NotFound("the run"))?;
    for step in &mut record.run.steps {
        if step.name == step_name {
            step.runner = Some(runner_id.clone());
        }
    }
    record.pinned_steps.remove(step_name);
    let run = record.run.clone();
    let follow_up = record.follow_ups.get(step_name).copied();
    if let Some(runner) = state.runners.get_mut(runner_id) {
        runner.slots_busy = runner.slots_busy.saturating_add(1);
    }
    build_assignment(state, run, step_name, follow_up)
}

fn build_assignment(
    state: &StoredState,
    run: Run,
    step_name: &str,
    follow_up: Option<FollowUp>,
) -> Result<RunAssignment, ServerError> {
    let task = state
        .tasks
        .get(&run.task_id)
        .ok_or(ServerError::NotFound("the task"))?;
    let workspace_id = find_task_workspace(state, task)?;
    let project = find_task_project(state, task)?;
    let (skills, rules) = match project {
        Some(project) => list_project_library(state, project),
        None => (Vec::new(), Vec::new()),
    };
    Ok(RunAssignment {
        step_name: step_name.to_owned(),
        workflow: run_workflow(state, task).cloned(),
        task: task.clone(),
        workspace_id,
        workspace_approval_policy: find_workspace_approval_policy(
            state,
            workspace_id,
        )?,
        project: project.cloned(),
        skills,
        rules,
        run,
        follow_up,
        protected_files: find_workspace_protected_files(state, workspace_id)?,
    })
}

fn list_project_library(
    state: &StoredState,
    project: &Project,
) -> (Vec<Skill>, Vec<Rule>) {
    let workspace_id = project.workspace_id;
    let project_id = project.id;
    let skills = state
        .skills
        .values()
        .filter(|skill| applies_to(&skill.scope, workspace_id, project_id))
        .cloned()
        .collect();
    let rules = state
        .rules
        .values()
        .filter(|rule| applies_to(&rule.scope, workspace_id, project_id))
        .cloned()
        .collect();
    (skills, rules)
}
