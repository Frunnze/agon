use orchestration_core::run::ChatMessage;

use crate::agent_invocation::{AgentEnding, invoke_agent};
use crate::agent_transcript::AgentTranscript;
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::runner_server::RunnerServer;
use crate::step_plan::StepPlan;

pub(crate) struct StepProgress {
    pub(crate) ending: AgentEnding,
    pub(crate) answered_messages: usize,
}

pub(crate) async fn answer_user_messages<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    first_ending: AgentEnding,
    already_answered: usize,
) -> Result<StepProgress, RunError> {
    let mut ending = first_ending;
    let mut answered_messages = already_answered;

    while let AgentEnding::Succeeded(transcript) = &ending {
        let server = context.server.as_ref();
        let user_messages = server.read_user_messages(context.run_id).await?;
        let unanswered =
            user_messages.get(answered_messages..).unwrap_or_default();
        if unanswered.is_empty() {
            break;
        }

        let next_ending =
            answer_messages(context, step, transcript.clone(), unanswered)
                .await?;
        answered_messages = user_messages.len();
        ending = next_ending;
    }

    Ok(StepProgress {
        ending,
        answered_messages,
    })
}

async fn answer_messages<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    transcript: AgentTranscript,
    user_messages: &[ChatMessage],
) -> Result<AgentEnding, RunError> {
    let mut latest = transcript;
    for user_message in user_messages {
        if user_message.text.trim().is_empty() {
            continue;
        }

        let session = latest.session.clone();
        let prompt = &user_message.text;
        let reply =
            invoke_agent(context, step, prompt, session.as_deref()).await?;
        latest = match reply {
            AgentEnding::Succeeded(reply) => latest.continue_with(reply),
            unfinished => return Ok(unfinished),
        };
    }
    Ok(AgentEnding::Succeeded(latest))
}
