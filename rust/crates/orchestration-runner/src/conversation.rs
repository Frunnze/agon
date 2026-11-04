use crate::agent_invocation::{AgentEnding, invoke_agent};
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::runner_server::RunnerServer;
use crate::step_plan::StepPlan;
use crate::user_message_watch::collect_new_user_messages;

pub(crate) async fn answer_user_messages<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    first_ending: AgentEnding,
) -> Result<AgentEnding, RunError> {
    let mut ending = first_ending;

    while let AgentEnding::Succeeded(transcript) = &ending {
        let server = context.server.as_ref();
        let user_messages = server.read_user_messages(context.run_id).await?;
        let new_messages = collect_new_user_messages(
            &user_messages,
            transcript.answered_messages,
        );
        let Some(new_messages) = new_messages else {
            break;
        };

        let reply = invoke_agent(
            context,
            step,
            &new_messages.prompt,
            transcript.session.as_deref(),
            new_messages.answered_messages,
        )
        .await?;
        ending = match reply {
            AgentEnding::Succeeded(reply) => {
                AgentEnding::Succeeded(transcript.clone().continue_with(reply))
            }
            unfinished => unfinished,
        };
    }

    Ok(ending)
}
