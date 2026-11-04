use std::time::Duration;

use orchestration_core::identifiers::RunId;
use orchestration_core::run::ChatMessage;

use crate::runner_log::log_user_message_check_failure;
use crate::runner_server::RunnerServer;
use crate::steady_interval::steady_interval;

const MESSAGE_SEPARATOR: &str = "\n\n";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NewUserMessages {
    pub prompt: String,
    pub answered_messages: usize,
}

#[must_use]
pub fn collect_new_user_messages(
    user_messages: &[ChatMessage],
    answered_messages: usize,
) -> Option<NewUserMessages> {
    let unanswered =
        user_messages.get(answered_messages..).unwrap_or_default();
    let mut spoken_texts = Vec::new();
    for user_message in unanswered {
        if !user_message.text.trim().is_empty() {
            spoken_texts.push(user_message.text.as_str());
        }
    }
    if spoken_texts.is_empty() {
        return None;
    }

    Some(NewUserMessages {
        prompt: spoken_texts.join(MESSAGE_SEPARATOR),
        answered_messages: user_messages.len(),
    })
}

pub(crate) async fn wait_for_new_user_messages<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    answered_messages: usize,
    check_interval: Duration,
) -> NewUserMessages {
    let mut timer = steady_interval(check_interval);
    loop {
        timer.tick().await;
        match server.read_user_messages(run_id).await {
            Ok(user_messages) => {
                let new_messages = collect_new_user_messages(
                    &user_messages,
                    answered_messages,
                );
                if let Some(new_messages) = new_messages {
                    return new_messages;
                }
            }
            Err(problem) => log_user_message_check_failure(run_id, &problem),
        }
    }
}
