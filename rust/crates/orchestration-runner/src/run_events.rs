use chrono::{DateTime, Utc};
use orchestration_api::work::{RunEvent, RunEventsRequest};
use orchestration_core::identifiers::RunId;
use orchestration_core::run::{ChatAuthor, ChatMessage, StepStatus};

use crate::runner_server::{RunnerServer, ServerError};

pub(crate) async fn post_run_events<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    events: Vec<RunEvent>,
) -> Result<(), ServerError> {
    let request = RunEventsRequest { events };
    server.post_run_events(run_id, &request).await
}

pub(crate) fn step_status_changed(
    step_name: &str,
    status: StepStatus,
) -> RunEvent {
    RunEvent::StepStatusChanged {
        step_name: step_name.to_string(),
        status,
    }
}

pub(crate) fn chat_appended(
    author: ChatAuthor,
    text: &str,
    at: DateTime<Utc>,
) -> RunEvent {
    RunEvent::ChatAppended {
        message: ChatMessage {
            at,
            author,
            text: text.to_string(),
            is_error: false,
            waiting_to_send: false,
        },
    }
}
