use crate::run_error::RunError;
use crate::run_workspace::{RunWorkspace, remove_idle_task_folder};
use crate::step_plan::StepPlan;
use crate::uncommitted_changes::{
    combine_change_commit_subjects, commit_uncommitted_changes,
    compose_change_commit_subject,
};
use crate::working_steps::Departure;

pub(crate) async fn leave_worktree(workspace: &RunWorkspace) {
    let mut steps_in_folder = workspace.working_steps.lock().await;
    if steps_in_folder.leave() == Departure::LastOut {
        remove_idle_task_folder(workspace);
    }
}

pub(crate) async fn leave_worktree_with_changes(
    workspace: &RunWorkspace,
    step: &StepPlan,
) -> Result<Departure, RunError> {
    let step_subject = compose_change_commit_subject(&step.name, step.agent);
    let mut steps_in_folder = workspace.working_steps.lock().await;
    let departure = steps_in_folder.leave_with_changes(step_subject);
    if departure == Departure::OthersStillWorking {
        return Ok(departure);
    }

    let step_subjects = steps_in_folder.take_uncommitted_step_subjects();
    let subject = combine_change_commit_subjects(&step_subjects);
    commit_every_checkout(workspace, &subject).await?;
    remove_idle_task_folder(workspace);
    Ok(departure)
}

async fn commit_every_checkout(
    workspace: &RunWorkspace,
    subject: &str,
) -> Result<(), RunError> {
    for checkout in &workspace.checkouts {
        let committed =
            commit_uncommitted_changes(&checkout.worktree, subject).await;
        if let Err(source) = committed {
            let repository = checkout.repository.address.clone();
            return Err(RunError::ChangesNotCommitted { repository, source });
        }
    }
    Ok(())
}
