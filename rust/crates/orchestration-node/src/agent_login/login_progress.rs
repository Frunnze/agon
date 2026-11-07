use std::fmt;

use orchestration_hub::terminal_screen::{TerminalScreen, TerminalSize};
use zeroize::Zeroizing;

use super::long_lived_tokens::find_long_lived_token;

pub(super) const LOGIN_TERMINAL_SIZE: TerminalSize = TerminalSize {
    columns: 512,
    rows: 40,
};
const LINE_SEPARATOR: &str = "\n";

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) enum LoginEnding {
    Finished,
    Failed(String),
}

pub struct LoginProgress {
    pub(super) screen: TerminalScreen,
    pub(super) seen_token: Option<Zeroizing<String>>,
    pub(super) has_exited: bool,
    pub(super) is_stop_requested: bool,
    pub(super) ending: Option<LoginEnding>,
}

impl Default for LoginProgress {
    fn default() -> Self {
        Self {
            screen: TerminalScreen::new(LOGIN_TERMINAL_SIZE),
            seen_token: None,
            has_exited: false,
            is_stop_requested: false,
            ending: None,
        }
    }
}

impl LoginProgress {
    pub fn take_output(&mut self, text: &str) {
        self.screen.feed(text);
        let shown_text = self.screen.lines().join(LINE_SEPARATOR);
        if let Some(token) = find_long_lived_token(&shown_text) {
            self.seen_token = Some(Zeroizing::new(token));
        }
    }
}

impl fmt::Debug for LoginProgress {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("LoginProgress")
            .field("has_exited", &self.has_exited)
            .field("is_stop_requested", &self.is_stop_requested)
            .field("ending", &self.ending)
            .finish_non_exhaustive()
    }
}
