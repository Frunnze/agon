use std::sync::{MutexGuard, PoisonError};

use super::Node;
#[cfg(feature = "app-server")]
use crate::node_error::NodeError;

impl Node {
    #[cfg(feature = "app-server")]
    pub(crate) fn record_hosting_problem(&self, problem: &NodeError) {
        *self.lock_hosting_problem() = Some(problem.to_string());
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn forget_hosting_problem(&self) {
        *self.lock_hosting_problem() = None;
    }

    pub(crate) fn hosting_problem(&self) -> Option<String> {
        self.lock_hosting_problem().clone()
    }

    fn lock_hosting_problem(&self) -> MutexGuard<'_, Option<String>> {
        self.hosting_problem
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}
