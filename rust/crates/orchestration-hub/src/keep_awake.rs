use std::fmt;

use keepawake::{Builder, KeepAwake};
use thiserror::Error;

const KEEP_AWAKE_REASON: &str = "Agent runs are in progress";
const APPLICATION_NAME: &str = "Agon";
const APPLICATION_REVERSE_DOMAIN: &str = "dev.agents-orchestration.runner";

pub struct KeepAwakeGuard {
    _sleep_prevention: KeepAwake,
}

#[derive(Debug, Error)]
pub enum KeepAwakeError {
    #[error("could not keep the computer awake: {0}")]
    Unavailable(String),
}

impl KeepAwakeGuard {
    pub fn acquire() -> Result<Self, KeepAwakeError> {
        let sleep_prevention = Builder::default()
            .idle(true)
            .reason(KEEP_AWAKE_REASON)
            .app_name(APPLICATION_NAME)
            .app_reverse_domain(APPLICATION_REVERSE_DOMAIN)
            .create()
            .map_err(|problem| {
                KeepAwakeError::Unavailable(problem.to_string())
            })?;
        Ok(Self {
            _sleep_prevention: sleep_prevention,
        })
    }
}

impl fmt::Debug for KeepAwakeGuard {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("KeepAwakeGuard")
            .finish_non_exhaustive()
    }
}
