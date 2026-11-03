use orchestration_hub::process_supervisor::SupervisorError;
use orchestration_hub::worktree_plan::WorktreeProblem;
use orchestration_hub::worktrees::WorktreeError;
use thiserror::Error;
use tokio::task::JoinError;

use crate::agents_file::AgentsFileError;
use crate::git_command::GitError;
use crate::runner_server::ServerError;
use crate::step_command::StepCommandError;
use crate::step_outcome::OutcomeProblem;
use crate::step_plan::AssignmentProblem;

#[derive(Debug, Error)]
pub(crate) enum RunError {
    #[error(transparent)]
    Assignment(#[from] AssignmentProblem),
    #[error(transparent)]
    WorktreePlan(#[from] WorktreeProblem),
    #[error("could not create the worktree: {0}")]
    Worktree(#[from] WorktreeError),
    #[error(transparent)]
    AgentsFile(#[from] AgentsFileError),
    #[error(transparent)]
    Command(#[from] StepCommandError),
    #[error(transparent)]
    Process(#[from] SupervisorError),
    #[error(transparent)]
    Server(#[from] ServerError),
    #[error(transparent)]
    Git(#[from] GitError),
    #[error(transparent)]
    Outcome(#[from] OutcomeProblem),
    #[error("could not commit the changes left in {repository}: {source}")]
    ChangesNotCommitted {
        repository: String,
        #[source]
        source: GitError,
    },
    #[error("a background task stopped unexpectedly: {0}")]
    BackgroundTask(#[from] JoinError),
    #[error("this runner does not offer where the task's agents run")]
    PlaceNotOffered,
    #[error("the agent stopped reading what the runner sends it")]
    AgentInputClosed,
}
