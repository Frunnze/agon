use orchestration_api::work::RunAssignment;
use orchestration_core::run::{ChatAuthor, Run};

use crate::agent_invocation::AgentEnding;
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::run_executor::RunOutcome;
use crate::run_reports::report_step_failure;
use crate::runner_server::RunnerServer;
use crate::skill_selection::select_step_skills;
use crate::step_execution::execute_step;
use crate::step_plan::StepPlan;
use crate::step_prompt::{UpstreamResult, compose_step_prompt};

pub(crate) async fn run_assigned_step<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    assignment: &RunAssignment,
    step: &StepPlan,
) -> RunOutcome {
    let prompt = prompt_for_step(step, assignment);
    let answered_messages = count_user_messages(&assignment.run);
    let progress =
        execute_step(context, step, &prompt, answered_messages).await;

    match progress.ending {
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

fn count_user_messages(run: &Run) -> usize {
    run.chat
        .iter()
        .filter(|message| message.author == ChatAuthor::You)
        .count()
}

fn prompt_for_step(step: &StepPlan, assignment: &RunAssignment) -> String {
    let skills = match &assignment.project {
        Some(project) => select_step_skills(
            step,
            &assignment.skills,
            project.workspace_id,
            project.id,
        ),
        None => Vec::new(),
    };
    let upstream_results = collect_upstream_results(step, &assignment.run);
    compose_step_prompt(
        &step.instruction,
        &assignment.task.details,
        &skills,
        &upstream_results,
    )
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
    upstream_results
}
