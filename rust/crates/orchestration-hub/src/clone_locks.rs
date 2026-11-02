use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

#[derive(Debug, Default)]
pub struct CloneLocks {
    locks: Mutex<HashMap<PathBuf, Arc<Mutex<()>>>>,
}

impl CloneLocks {
    pub(crate) fn lock_for(&self, cached_clone: &Path) -> Arc<Mutex<()>> {
        let mut locks = hold_lock(&self.locks);
        let clone_lock = locks.entry(cached_clone.to_path_buf()).or_default();
        Arc::clone(clone_lock)
    }
}

pub(crate) fn hold_lock<T>(lock: &Mutex<T>) -> MutexGuard<'_, T> {
    lock.lock().unwrap_or_else(PoisonError::into_inner)
}
