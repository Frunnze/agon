use std::collections::BTreeSet;
use std::sync::{Mutex, MutexGuard, PoisonError};

use orchestration_security::pairing::PairingCode;

use crate::node_error::NodeError;

#[derive(Debug)]
struct CodeProblem {
    code: String,
    description: String,
}

#[derive(Debug, Default)]
struct PublishedState {
    codes: BTreeSet<String>,
    problem: Option<CodeProblem>,
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

    pub(crate) fn record_problem(
        &self,
        code: &PairingCode,
        problem: &NodeError,
    ) {
        let code_problem = CodeProblem {
            code: String::from(code.clone()),
            description: problem.to_string(),
        };
        self.lock_state().problem = Some(code_problem);
    }

    pub(crate) fn forget_problem_of(&self, code: &PairingCode) {
        let canonical_code = String::from(code.clone());
        let mut state = self.lock_state();
        let describes_the_code = state
            .problem
            .as_ref()
            .is_some_and(|problem| problem.code == canonical_code);
        if describes_the_code {
            state.problem = None;
        }
    }

    pub(crate) fn problem(&self) -> Option<String> {
        let state = self.lock_state();
        let problem = state.problem.as_ref()?;
        Some(problem.description.clone())
    }

    fn lock_state(&self) -> MutexGuard<'_, PublishedState> {
        self.state.lock().unwrap_or_else(PoisonError::into_inner)
    }
}
