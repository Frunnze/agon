use std::collections::BTreeSet;

use orchestration_api::work::{ForgottenWork, HeartbeatRequest};

use crate::stored_state::StoredState;

pub fn find_forgotten_work(
    state: &StoredState,
    heartbeat: &HeartbeatRequest,
) -> ForgottenWork {
    let mut forgotten_tasks = Vec::new();
    for task_id in &heartbeat.held_tasks {
        if !state.tasks.contains_key(task_id) {
            forgotten_tasks.push(*task_id);
        }
    }

    let used_addresses = list_used_addresses(state);
    let mut unused_repositories = Vec::new();
    for address in &heartbeat.cached_repositories {
        if !used_addresses.contains(address.as_str()) {
            unused_repositories.push(address.clone());
        }
    }

    ForgottenWork {
        forgotten_tasks,
        unused_repositories,
    }
}

fn list_used_addresses(state: &StoredState) -> BTreeSet<&str> {
    let mut used_addresses = BTreeSet::new();
    for project in state.projects.values() {
        for repository in &project.repositories {
            used_addresses.insert(repository.address.as_str());
        }
    }
    used_addresses
}
