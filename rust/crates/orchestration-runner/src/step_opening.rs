use orchestration_api::work::RunAssignment;
use orchestration_core::run::ChatAuthor;

use crate::agent_invocation::{AgentEnding, invoke_agent};
use crate::agent_transcript::AgentTranscript;
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::runner_server::RunnerServer;
use crate::step_plan::StepPlan;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum StepOpening {
    FreshPrompt(String),
    ResumedSession(String),
}

#[must_use]
pub fn choose_step_opening(
    assignment: &RunAssignment,
    fresh_prompt: String,
) -> StepOpening {
    let kept_session = &assignment.run.agent_session;
    match (&assignment.follow_up, kept_session) {
        (Some(_), Some(session)) => {
            StepOpening::ResumedSession(session.clone())
        }
        _ => StepOpening::FreshPrompt(fresh_prompt),
    }
}

#[must_use]
pub fn count_answered_messages(assignment: &RunAssignment) -> usize {
    if let Some(follow_up) = &assignment.follow_up {
        return follow_up.answered_user_messages;
    }
    assignment
        .run
        .chat
        .iter()
        .filter(|message| message.author == ChatAuthor::You)
        .count()
}

pub(crate) async fn open_agent_conversation<
    S: RunnerServer,
    P: BranchPusher,
>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    opening: &StepOpening,
) -> Result<AgentEnding, RunError> {
    match opening {
        StepOpening::FreshPrompt(prompt) => {
            invoke_agent(context, step, prompt, None).await
        }
        StepOpening::ResumedSession(session) => {
            let transcript = AgentTranscript {
                session: Some(session.clone()),
                ..AgentTranscript::default()
            };
            Ok(AgentEnding::Succeeded(transcript))
        }
    }
}
