use std::collections::BTreeMap;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::thread;

use orchestration_core::agent_place::AgentPlace;
use orchestration_hub::agent_command::CLAUDE_PROGRAM;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::interactive_terminal::{
    TerminalKeyboard, TerminalProcess, TerminalStopper,
    start_interactive_terminal,
};
use orchestration_hub::terminal_screen::{TerminalScreen, TerminalSize};
use serde::Serialize;
use tokio::sync::mpsc::UnboundedReceiver;
use zeroize::Zeroizing;

use super::login_outcome::{LoginOutcome, decide_login_outcome};
use super::long_lived_tokens::{
    find_long_lived_token, hide_long_lived_tokens,
};
use crate::agent_credentials::AgentCredentials;
use crate::node_error::NodeError;

const LOGIN_TERMINAL_SIZE: TerminalSize = TerminalSize {
    columns: 512,
    rows: 40,
};
const LOCAL_LOGIN_ARGUMENTS: &[&str] = &["auth", "login"];
const CONTAINER_LOGIN_ARGUMENTS: &[&str] = &["setup-token"];
const WORD_SEPARATOR: &str = " ";
const LINE_SEPARATOR: &str = "\n";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LoginState {
    Running,
    Finished,
    Failed,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct AgentLoginView {
    pub place: AgentPlace,
    pub command: String,
    pub lines: Vec<String>,
    pub state: LoginState,
    pub problem: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum LoginEnding {
    Finished,
    Failed(String),
}

#[derive(Debug)]
struct LoginProgress {
    screen: TerminalScreen,
    seen_token: Option<Zeroizing<String>>,
    has_exited: bool,
    ending: Option<LoginEnding>,
}

#[derive(Debug)]
struct LoginFollower {
    place: AgentPlace,
    progress: Arc<Mutex<LoginProgress>>,
    credentials: Arc<AgentCredentials>,
}

#[derive(Debug)]
pub(crate) struct LoginSession {
    place: AgentPlace,
    keyboard: TerminalKeyboard,
    stopper: TerminalStopper,
    progress: Arc<Mutex<LoginProgress>>,
}

impl LoginSession {
    pub(crate) fn start(
        place: AgentPlace,
        credentials: Arc<AgentCredentials>,
    ) -> Result<Self, NodeError> {
        let terminal = start_interactive_terminal(
            &describe_login_command(place),
            LOGIN_TERMINAL_SIZE,
        )
        .map_err(|problem| NodeError::LoginTerminal(problem.to_string()))?;
        let progress = Arc::new(Mutex::new(LoginProgress {
            screen: TerminalScreen::new(LOGIN_TERMINAL_SIZE),
            seen_token: None,
            has_exited: false,
            ending: None,
        }));
        let follower = LoginFollower {
            place,
            progress: Arc::clone(&progress),
            credentials,
        };
        let output = terminal.output;
        let process = terminal.process;
        thread::spawn(move || follower.follow(output, process));
        Ok(Self {
            place,
            keyboard: terminal.keyboard,
            stopper: terminal.stopper,
            progress,
        })
    }

    pub(crate) fn has_ended(&self) -> bool {
        lock_progress(&self.progress).ending.is_some()
    }

    pub(crate) fn view(&self) -> AgentLoginView {
        let progress = lock_progress(&self.progress);
        let lines = progress
            .screen
            .lines()
            .iter()
            .map(|line| hide_long_lived_tokens(line))
            .collect();
        let (state, problem) = match &progress.ending {
            None => (LoginState::Running, None),
            Some(LoginEnding::Finished) => (LoginState::Finished, None),
            Some(LoginEnding::Failed(problem)) => {
                (LoginState::Failed, Some(problem.clone()))
            }
        };
        AgentLoginView {
            place: self.place,
            command: describe_command_text(self.place),
            lines,
            state,
            problem,
        }
    }

    pub(crate) fn type_keys(&mut self, keys: &str) -> Result<(), NodeError> {
        self.keyboard
            .send_keys(keys)
            .map_err(|problem| NodeError::LoginTerminal(problem.to_string()))
    }

    pub(crate) fn stop(&mut self) -> Result<(), NodeError> {
        if lock_progress(&self.progress).has_exited {
            return Ok(());
        }
        let stopped = self.stopper.stop();
        let has_exited_meanwhile = lock_progress(&self.progress).has_exited;
        match stopped {
            Err(problem) if !has_exited_meanwhile => {
                Err(NodeError::LoginTerminal(problem.to_string()))
            }
            _ => Ok(()),
        }
    }
}

impl LoginFollower {
    fn follow(
        self,
        mut output: UnboundedReceiver<String>,
        mut process: TerminalProcess,
    ) {
        while let Some(text) = output.blocking_recv() {
            self.take_output(&text);
        }
        let exit = process.wait_for_exit();
        let seen_token = {
            let mut progress = lock_progress(&self.progress);
            progress.has_exited = true;
            progress.seen_token.clone()
        };
        let ending = match exit {
            Ok(exit) => {
                let token = seen_token.as_deref().map(String::as_str);
                let outcome = decide_login_outcome(self.place, &exit, token);
                self.settle(outcome)
            }
            Err(problem) => LoginEnding::Failed(problem.to_string()),
        };
        lock_progress(&self.progress).ending = Some(ending);
    }

    fn take_output(&self, text: &str) {
        let mut progress = lock_progress(&self.progress);
        progress.screen.feed(text);
        let shown_text = progress.screen.lines().join(LINE_SEPARATOR);
        if let Some(token) = find_long_lived_token(&shown_text) {
            progress.seen_token = Some(Zeroizing::new(token));
        }
    }

    fn settle(&self, outcome: LoginOutcome) -> LoginEnding {
        match outcome {
            LoginOutcome::LoggedIn => LoginEnding::Finished,
            LoginOutcome::Connected(credential) => {
                match self.credentials.keep(credential) {
                    Ok(()) => LoginEnding::Finished,
                    Err(problem) => LoginEnding::Failed(problem.to_string()),
                }
            }
            LoginOutcome::Failed(problem) => LoginEnding::Failed(problem),
        }
    }
}

fn choose_login_arguments(place: AgentPlace) -> &'static [&'static str] {
    match place {
        AgentPlace::LocalProcess => LOCAL_LOGIN_ARGUMENTS,
        AgentPlace::Container => CONTAINER_LOGIN_ARGUMENTS,
    }
}

fn describe_login_command(place: AgentPlace) -> CommandSpecification {
    let arguments = choose_login_arguments(place)
        .iter()
        .map(ToString::to_string)
        .collect();
    CommandSpecification {
        program: CLAUDE_PROGRAM.to_owned(),
        arguments,
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn describe_command_text(place: AgentPlace) -> String {
    let mut words = vec![CLAUDE_PROGRAM];
    words.extend_from_slice(choose_login_arguments(place));
    words.join(WORD_SEPARATOR)
}

fn lock_progress(
    progress: &Mutex<LoginProgress>,
) -> MutexGuard<'_, LoginProgress> {
    progress.lock().unwrap_or_else(PoisonError::into_inner)
}
