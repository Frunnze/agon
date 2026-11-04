use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};

use crate::working_steps::WorkingSteps;

pub(crate) type SharedWorkingSteps = Arc<tokio::sync::Mutex<WorkingSteps>>;

#[derive(Debug, Default)]
pub(crate) struct WorktreeLocks {
    working_steps_by_folder: Mutex<HashMap<PathBuf, SharedWorkingSteps>>,
}

impl WorktreeLocks {
    pub(crate) fn working_steps_for(
        &self,
        task_folder: &Path,
    ) -> SharedWorkingSteps {
        let mut working_steps_by_folder = self
            .working_steps_by_folder
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let working_steps = working_steps_by_folder
            .entry(task_folder.to_path_buf())
            .or_default();
        Arc::clone(working_steps)
    }
}
