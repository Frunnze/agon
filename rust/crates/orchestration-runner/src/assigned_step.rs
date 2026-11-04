use orchestration_api::work::RunAssignment;
use orchestration_core::library::Skill;

use crate::agent_invocation::AgentEnding;
use crate::assignment_prompt::compose_assignment_prompt;
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::run_executor::RunOutcome;
use crate::run_reports::report_step_failure;
use crate::run_workspace::RunWorkspace;
use crate::runner_server::RunnerServer;
use crate::skill_selection::select_step_skills;
use crate::step_execution::execute_step;
use crate::step_opening::{choose_step_opening, count_answered_messages};
use crate::step_plan::StepPlan;

pub(crate) async fn run_assigned_step<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    assignment: &RunAssignment,
    step: &StepPlan,
) -> RunOutcome {
    let repository_folders = name_repository_folders(&context.workspace);
    let skills = select_assigned_skills(step, assignment);
    let prompt = compose_assignment_prompt(
        step,
        assignment,
        &repository_folders,
        &skills,
    );
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
