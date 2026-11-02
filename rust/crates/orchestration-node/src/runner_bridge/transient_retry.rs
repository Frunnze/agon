use std::time::Duration;

use crate::node_error::NodeError;

pub const FIRST_RETRY_DELAY: Duration = Duration::from_millis(500);
pub const LONGEST_RETRY_DELAY: Duration = Duration::from_secs(30);
const RETRY_GROWTH_FACTOR: u32 = 2;
const FIRST_SERVER_ERROR_STATUS: u16 = 500;
const LAST_SERVER_ERROR_STATUS: u16 = 599;

#[must_use]
pub fn is_transient_failure(problem: &NodeError) -> bool {
    match problem {
        NodeError::ServerUnreachable(_) => true,
        NodeError::ServerRejected { status, .. } => (FIRST_SERVER_ERROR_STATUS
            ..=LAST_SERVER_ERROR_STATUS)
            .contains(status),
        _ => false,
    }
}

#[must_use]
pub fn next_retry_delay(previous_delay: Duration) -> Duration {
    let grown_delay = previous_delay.saturating_mul(RETRY_GROWTH_FACTOR);
    grown_delay.min(LONGEST_RETRY_DELAY)
}

pub async fn retry_transient<Answer, Attempt>(
    mut attempt: impl FnMut() -> Attempt,
) -> Result<Answer, NodeError>
where
    Attempt: Future<Output = Result<Answer, NodeError>>,
{
    let mut delay = FIRST_RETRY_DELAY;
    loop {
        match attempt().await {
            Err(problem) if is_transient_failure(&problem) => {
                tokio::time::sleep(delay).await;
                delay = next_retry_delay(delay);
            }
            outcome => return outcome,
        }
    }
}
