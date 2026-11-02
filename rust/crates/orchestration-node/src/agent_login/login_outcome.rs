use orchestration_hub::process_supervisor::ProcessExit;

use crate::agent_credentials::{AgentCredential, AgentCredentialKind};
use crate::runner_settings::AgentPlace;

const NO_TOKEN_PROBLEM: &str = "Claude Code finished without a token";
const STOPPED_PROBLEM: &str = "the login was stopped";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum LoginOutcome {
    LoggedIn,
    Connected(AgentCredential),
    Failed(String),
}

#[must_use]
pub fn decide_login_outcome(
    place: AgentPlace,
    exit: &ProcessExit,
    seen_token: Option<&str>,
) -> LoginOutcome {
    match (place, seen_token) {
        (AgentPlace::Container, Some(token)) => connect_with(token),
        (AgentPlace::Container, None) => {
            LoginOutcome::Failed(describe_tokenless_exit(exit))
        }
        (AgentPlace::LocalProcess, _) if *exit == ProcessExit::Succeeded => {
            LoginOutcome::LoggedIn
        }
        (AgentPlace::LocalProcess, _) => {
            LoginOutcome::Failed(describe_tokenless_exit(exit))
        }
    }
}

fn connect_with(token: &str) -> LoginOutcome {
    match AgentCredential::new(AgentCredentialKind::LongLivedToken, token) {
        Ok(credential) => LoginOutcome::Connected(credential),
        Err(problem) => LoginOutcome::Failed(problem.to_string()),
    }
}

fn describe_tokenless_exit(exit: &ProcessExit) -> String {
    match exit {
        ProcessExit::Succeeded => NO_TOKEN_PROBLEM.to_owned(),
        ProcessExit::FailedWithCode(code) => {
            format!("Claude Code stopped with code {code}")
        }
        ProcessExit::KilledBySignal(_) => STOPPED_PROBLEM.to_owned(),
    }
}
