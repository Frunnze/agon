use std::collections::BTreeSet;
use std::sync::{Mutex, MutexGuard, PoisonError};

use orchestration_security::pairing::PairingCode;

use crate::node_error::NodeError;

#[derive(Debug, Default)]
struct PublishedState {
    codes: BTreeSet<String>,
    problem: Option<String>,
}

#[derive(Debug, Default)]
pub(crate) struct PublishedCodes {
    state: Mutex<PublishedState>,
}

impl PublishedCodes {
    pub(crate) fn record_published(&self, code: &PairingCode) {
        let mut state = self.lock_state();
        state.codes.insert(String::from(code.clone()));
        state.problem = None;
    }

    pub(crate) fn take(&self, code: &PairingCode) -> bool {
        let canonical_code = String::from(code.clone());
        self.lock_state().codes.remove(&canonical_code)
    }

    pub(crate) fn record_problem(&self, problem: &NodeError) {
        self.lock_state().problem = Some(problem.to_string());
    }

    pub(crate) fn problem(&self) -> Option<String> {
        self.lock_state().problem.clone()
    }

    fn lock_state(&self) -> MutexGuard<'_, PublishedState> {
        self.state.lock().unwrap_or_else(PoisonError::into_inner)
    }
}
