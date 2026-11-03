use orchestration_api::work::RunEvent;
use orchestration_core::run::StepStatus;

use crate::agent_invocation::AgentEnding;
use crate::agent_transcript::AgentTranscript;
use crate::branch_pusher::BranchPusher;
use crate::commit_publishing::{Publishing, publish_commits};
use crate::conversation::{StepProgress, answer_user_messages};
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::{post_run_events, step_status_changed};
use crate::runner_server::RunnerServer;
use crate::step_opening::{StepOpening, open_agent_conversation};
use crate::step_outcome::{OutcomeProblem, read_reported_outcome};
use crate::step_plan::StepPlan;
use crate::uncommitted_changes::{
    commit_uncommitted_changes, compose_change_commit_subject,
};

pub(crate) async fn execute_step<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    opening: &StepOpening,
    answered_messages: usize,
) -> StepProgress {
    let attempt =
        attempt_step(context, step, opening, answered_messages).await;
    match attempt {
        Ok(progress) => progress,
        Err(problem) => StepProgress {
            ending: AgentEnding::Failed(problem.to_string()),
            answered_messages,
        },
    }
}

async fn attempt_step<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    opening: &StepOpening,
    answered_messages: usize,
) -> Result<StepProgress, RunError> {
    let server = context.server.as_ref();
    let running = step_status_changed(&step.name, StepStatus::Running);
    post_run_events(server, context.run_id, vec![running]).await?;

    let first_ending = open_agent_conversation(context, step, opening).await?;
    let conversation =
        answer_user_messages(context, step, first_ending, answered_messages)
            .await?;
    let answered_messages = conversation.answered_messages;
    let transcript = match conversation.ending {
        AgentEnding::Succeeded(transcript) => transcript,
        unfinished => {
            return Ok(StepProgress {
                ending: unfinished,
                answered_messages,
            });
        }
    };

    let outcome = read_step_outcome(step, &transcript)?;
    commit_agent_changes(context, step).await?;
    if publish_commits(context, step).await? == Publishing::Cancelled {
        return Ok(StepProgress {
            ending: AgentEnding::Cancelled,
            answered_messages,
        });
    }

    let mut finishing_events = Vec::new();
    if let Some(final_message) = &transcript.final_message {
        finishing_events.push(RunEvent::StepResultRecorded {
            step_name: step.name.clone(),
            result: final_message.clone(),
            outcome,
        });
    }
    finishing_events.push(step_status_changed(&step.name, StepStatus::Done));
    post_run_events(server, context.run_id, finishing_events).await?;
    Ok(StepProgress {
        ending: AgentEnding::Succeeded(transcript),
        answered_messages,
    })
}

fn read_step_outcome(
    step: &StepPlan,
    transcript: &AgentTranscript,
) -> Result<Option<String>, OutcomeProblem> {
    if step.outcome_choices.is_empty() {
        return Ok(None);
    }
    let final_message = transcript.final_message.as_deref();
    let outcome = read_reported_outcome(final_message, &step.outcome_choices)?;
    Ok(Some(outcome))
}

async fn commit_agent_changes<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
) -> Result<(), RunError> {
    let subject = compose_change_commit_subject(&step.name, step.agent);
    for checkout in &context.workspace.checkouts {
        let committed =
            commit_uncommitted_changes(&checkout.worktree, &subject).await;
        if let Err(source) = committed {
            let repository = checkout.repository.address.clone();
            return Err(RunError::ChangesNotCommitted { repository, source });
        }
    }
    Ok(())
}
