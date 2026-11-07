use std::time::Duration;

use serde_json::Value;

use super::hosting_steps::NO_SERVER_ACCEPTED_CODE;
use super::waiting::wait_for;

const CODE_JOIN_LIMIT: Duration = Duration::from_secs(90);
const CODE_JOIN_DESCRIPTION: &str = "an app server to accept the code";

fn keep_searching_when_unanswered(
    join_outcome: Result<Value, String>,
) -> Result<Option<Value>, String> {
    match join_outcome {
        Err(problem) if problem == NO_SERVER_ACCEPTED_CODE => Ok(None),
        finished_join => finished_join.map(Some),
    }
}

pub fn join_until_a_server_accepts(
    send_join: impl Fn() -> Result<Value, String>,
) -> Result<Value, String> {
    wait_for(CODE_JOIN_LIMIT, CODE_JOIN_DESCRIPTION, || {
        keep_searching_when_unanswered(send_join())
    })
}
