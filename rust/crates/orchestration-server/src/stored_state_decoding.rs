use std::collections::BTreeMap;

use orchestration_core::local_folders::is_local_address;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::workspace::{Project, Repository};

use crate::stored_state::StoredState;

pub fn decode_stored_state(
    state_bytes: &[u8],
) -> serde_json::Result<StoredState> {
    let decoded_state: StoredState = serde_json::from_slice(state_bytes)?;

    let mut canonical_projects = BTreeMap::new();
    for (project_id, project) in decoded_state.projects {
        let mut repositories = Vec::new();
        for repository in &project.repositories {
            repositories.push(canonicalise_repository(repository));
        }
        let canonical_project = Project {
            repositories,
            ..project
        };
        canonical_projects.insert(project_id, canonical_project);
    }

    Ok(StoredState {
        projects: canonical_projects,
        ..decoded_state
    })
}

fn canonicalise_repository(repository: &Repository) -> Repository {
    let stored_address = &repository.address;
    if is_local_address(stored_address) {
        return repository.clone();
    }
    let Ok(canonical_address) = parse_repository_address(stored_address)
    else {
        return repository.clone();
    };
    Repository {
        address: canonical_address,
        ..repository.clone()
    }
}
