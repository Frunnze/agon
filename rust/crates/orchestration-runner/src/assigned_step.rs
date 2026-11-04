use orchestration_api::work::RunAssignment;
use orchestration_core::library::Skill;
use orchestration_core::run::Run;

use crate::agent_invocation::AgentEnding;
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::run_executor::RunOutcome;
use crate::run_reports::report_step_failure;
use crate::run_workspace::RunWorkspace;
use crate::runner_server::RunnerServer;
use crate::skill_selection::select_step_skills;
use crate::step_execution::execute_step;
use crate::step_opening::{choose_step_opening, count_answered_messages};
use crate::step_outcome::compose_outcome_request;
use crate::step_plan::StepPlan;
use crate::step_prompt::{UpstreamResult, compose_step_prompt};

const OUTCOME_SEPARATOR: &str = "\n\n";

pub(crate) async fn run_assigned_step<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    assignment: &RunAssignment,
    step: &StepPlan,
) -> RunOutcome {
    let repository_folders = name_repository_folders(&context.workspace);
    let skills = select_assigned_skills(step, assignment);
    let prompt =
        prompt_for_step(step, assignment, &repository_folders, &skills);
    let opening = choose_step_opening(assignment, prompt);
    let answered_messages = count_answered_messages(assignment);
    let ending =
        execute_step(context, step, &skills, &opening, answered_messages)
            .await;

    match ending {
        AgentEnding::Succeeded(_) => RunOutcome::Finished,
        AgentEnding::Failed(reason) => {
            let server = context.server.as_ref();
            report_step_failure(server, context.run_id, &step.name, &reason)
                .await;
            RunOutcome::Failed
        }
        AgentEnding::Cancelled => RunOutcome::Cancelled,
    }
}

fn name_repository_folders(workspace: &RunWorkspace) -> Vec<String> {
    let mut folders = Vec::new();
    for checkout in &workspace.checkouts {
        if let Some(folder) = checkout.worktree.file_name() {
            folders.push(folder.to_string_lossy().into_owned());
        }
    }
    folders
}

fn select_assigned_skills<'assignment>(
    step: &StepPlan,
    assignment: &'assignment RunAssignment,
) -> Vec<&'assignment Skill> {
    let Some(project) = &assignment.project else {
        return Vec::new();
    };
    select_step_skills(
        step,
        &assignment.skills,
        project.workspace_id,
        project.id,
    )
}

fn prompt_for_step(
    step: &StepPlan,
    assignment: &RunAssignment,
    repository_folders: &[String],
    skills: &[&Skill],
) -> String {
    let upstream_results = collect_upstream_results(step, &assignment.run);
    let prompt = compose_step_prompt(
        &step.instruction,
        &assignment.task.details,
        repository_folders,
        skills,
        &upstream_results,
    );
    if step.outcome_choices.is_empty() {
        return prompt;
    }
    let outcome_request = compose_outcome_request(&step.outcome_choices);
    format!("{prompt}{OUTCOME_SEPARATOR}{outcome_request}")
}

fn collect_upstream_results(
    step: &StepPlan,
    run: &Run,
) -> Vec<UpstreamResult> {
    let mut upstream_results = Vec::new();
    for run_step in &run.steps {
        let is_upstream = step.upstream_step_names.contains(&run_step.name);
        if let (true, Some(result)) = (is_upstream, &run_step.result) {
            upstream_results.push(UpstreamResult {
                step_name: run_step.name.clone(),
                final_message: result.clone(),
            });
        }
    }
    if let Some(looped_result) = find_looped_result(step, run) {
        upstream_results.push(looped_result);
    }
    upstream_results
}

fn find_looped_result(step: &StepPlan, run: &Run) -> Option<UpstreamResult> {
    let own_step =
        run.steps.iter().find(|run_step| run_step.name == step.name);
    let loop_source = own_step?.loop_source.as_ref()?;
    let source_step = run
        .steps
        .iter()
        .find(|run_step| &run_step.name == loop_source)?;
    let last_round = source_step.earlier_rounds.last()?;
    let final_message = last_round.result.clone()?;
    Some(UpstreamResult {
        step_name: loop_source.clone(),
        final_message,
    })
}
