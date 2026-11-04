use std::time::Duration;

use crate::peer_error::PeerError;

pub const BOARD_RETRY_PAUSES: [Duration; 2] =
    [Duration::from_millis(500), Duration::from_secs(1)];
const TOO_MANY_REQUESTS_STATUS: u16 = 429;
const FIRST_SERVER_ERROR_STATUS: u16 = 500;
const LAST_SERVER_ERROR_STATUS: u16 = 599;

#[must_use]
pub fn is_transient_board_problem(problem: &PeerError) -> bool {
    match problem {
        PeerError::RecordBoardUnreachable(_) => true,
        PeerError::RecordRefused(status) => {
            let is_rate_limited = *status == TOO_MANY_REQUESTS_STATUS;
            let is_server_error = (FIRST_SERVER_ERROR_STATUS
                ..=LAST_SERVER_ERROR_STATUS)
                .contains(status);
            is_rate_limited || is_server_error
        }
        _ => false,
    }
}

pub async fn retry_transient_board_problems<Answer, Attempt>(
    mut attempt: impl FnMut() -> Attempt,
) -> Result<Answer, PeerError>
where
    Attempt: Future<Output = Result<Answer, PeerError>>,
{
    for pause in BOARD_RETRY_PAUSES {
        match attempt().await {
            Err(problem) if is_transient_board_problem(&problem) => {
                tokio::time::sleep(pause).await;
            }
            outcome => return outcome,
        }
    }
    attempt().await
}
