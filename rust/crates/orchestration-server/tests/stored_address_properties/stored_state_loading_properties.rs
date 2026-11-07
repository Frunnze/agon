use orchestration_core::local_folders::is_local_address;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use orchestration_server::StoredState;
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::address_strategies::canonical_address;
use crate::fixtures::{OWNER_SEED, identity_from_seed};
use crate::old_stored_addresses::{
    OldAddress, branch_name, distinct_old_addresses, list_addresses,
    list_canonical_addresses, list_stored_addresses, local_address,
    project_at, project_with, state_with, store_then_load,
};

const LOADING_CASES: u32 = 32;
const MOST_PROJECTS: usize = 3;
const UNREADABLE_ADDRESS: &str = "[ -~]{0,24}";

fn old_project(old_addresses: &[OldAddress]) -> Project {
    project_at(&list_stored_addresses(old_addresses))
}

fn load_project(state: &StoredState, project: &Project) -> Project {
    let directory = TempDir::new().expect("a directory exists");
    let loaded_state = store_then_load(directory.path(), state);
    loaded_state
        .projects
        .get(&project.id)
        .expect("the project is loaded")
        .clone()
}

fn agent_access() -> impl Strategy<Value = AgentAccess> {
    prop_oneof![
        Just(AgentAccess::ReadOnly),
        Just(AgentAccess::PushAfterApproval),
    ]
}

fn unreadable_address() -> impl Strategy<Value = String> {
    UNREADABLE_ADDRESS.prop_filter("the address does not parse", |address| {
        !is_local_address(address)
            && parse_repository_address(address).is_err()
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOADING_CASES))]

    #[test]
    fn test_load_state_property_reads_old_addresses_in_canonical_form(
        old_addresses in distinct_old_addresses(),
    ) {
        let project = old_project(&old_addresses);

        let loaded_project = load_project(&state_with(&project), &project);

        prop_assert_eq!(
            list_addresses(&loaded_project.repositories),
            list_canonical_addresses(&old_addresses)
        );
    }

    #[test]
    fn test_load_state_property_loaded_addresses_reparse_to_themselves(
        old_addresses in distinct_old_addresses(),
    ) {
        let project = old_project(&old_addresses);

        let loaded_project = load_project(&state_with(&project), &project);

        for address in list_addresses(&loaded_project.repositories) {
            prop_assert_eq!(parse_repository_address(&address), Ok(address));
        }
    }

    #[test]
    fn test_load_state_property_loading_again_changes_nothing(
        old_addresses in distinct_old_addresses(),
    ) {
        let project = old_project(&old_addresses);
        let directory = TempDir::new().expect("a directory exists");

        let old_state = state_with(&project);
        let first_load = store_then_load(directory.path(), &old_state);
        let second_load = store_then_load(directory.path(), &first_load);

        prop_assert_eq!(second_load, first_load);
    }

    #[test]
    fn test_decode_stored_state_property_canonicalises_every_project(
        projects_addresses in vec(distinct_old_addresses(), 1..=MOST_PROJECTS),
    ) {
        let mut state = StoredState::default();
        let mut projects = Vec::new();
        for old_addresses in &projects_addresses {
            let project = old_project(old_addresses);
            state.projects.insert(project.id, project.clone());
            projects.push(project);
        }
        let directory = TempDir::new().expect("a directory exists");

        let loaded_state = store_then_load(directory.path(), &state);

        prop_assert_eq!(loaded_state.projects.len(), projects.len());
        let project_pairs = projects.iter().zip(&projects_addresses);
        for (project, old_addresses) in project_pairs {
            let loaded_project = &loaded_state.projects[&project.id];
            prop_assert_eq!(
                list_addresses(&loaded_project.repositories),
                list_canonical_addresses(old_addresses)
            );
        }
    }

    #[test]
    fn test_decode_stored_state_property_keeps_every_other_field(
        old_addresses in distinct_old_addresses(),
        revision in any::<u64>(),
        latest_sequence in any::<u64>(),
    ) {
        let project = old_project(&old_addresses);
        let state = StoredState {
            revision,
            latest_sequence,
            ..state_with(&project)
        };
        let directory = TempDir::new().expect("a directory exists");

        let loaded_state = store_then_load(directory.path(), &state);

        let loaded_project = &loaded_state.projects[&project.id];
        prop_assert_eq!(loaded_state.revision, revision);
        prop_assert_eq!(loaded_state.latest_sequence, latest_sequence);
        prop_assert_eq!(loaded_project.id, project.id);
        prop_assert_eq!(loaded_project.workspace_id, project.workspace_id);
        prop_assert_eq!(&loaded_project.name, &project.name);
        prop_assert_eq!(
            loaded_project.approval_policy,
            project.approval_policy
        );
    }

    #[test]
    fn test_decode_stored_state_property_keeps_canonical_states_unchanged(
        addresses in vec(canonical_address(), 1..=MOST_PROJECTS),
    ) {
        let project = project_at(&addresses);
        let state = state_with(&project);
        let directory = TempDir::new().expect("a directory exists");

        let loaded_state = store_then_load(directory.path(), &state);

        prop_assert_eq!(loaded_state, state);
    }

    #[test]
    fn test_canonicalise_repository_property_keeps_local_folders_untouched(
        local_addresses in vec(
            local_address(&identity_from_seed(OWNER_SEED).device_id()),
            1..=MOST_PROJECTS,
        ),
    ) {
        let project = project_at(&local_addresses);

        let loaded_project = load_project(&state_with(&project), &project);

        prop_assert_eq!(
            list_addresses(&loaded_project.repositories),
            local_addresses
        );
    }

    #[test]
    fn test_canonicalise_repository_property_keeps_branch_and_access(
        old_addresses in distinct_old_addresses(),
        branches in vec(branch_name(), 1..=MOST_PROJECTS),
        accesses in vec(agent_access(), 1..=MOST_PROJECTS),
    ) {
        let mut repositories = Vec::new();
        let stored_addresses = list_stored_addresses(&old_addresses);
        for (index, stored_address) in stored_addresses.iter().enumerate() {
            repositories.push(Repository {
                address: stored_address.clone(),
                default_branch: branches[index % branches.len()].clone(),
                agent_access: accesses[index % accesses.len()],
            });
        }
        let project = project_with(repositories.clone());

        let loaded_project = load_project(&state_with(&project), &project);

        prop_assert_eq!(loaded_project.repositories.len(), repositories.len());
        let loaded_pairs =
            loaded_project.repositories.iter().zip(&repositories);
        for (loaded_repository, stored_repository) in loaded_pairs {
            prop_assert_eq!(
                &loaded_repository.default_branch,
                &stored_repository.default_branch
            );
            prop_assert_eq!(
                loaded_repository.agent_access,
                stored_repository.agent_access
            );
        }
    }

    #[test]
    fn test_canonicalise_repository_property_keeps_unreadable_addresses(
        unreadable_addresses in vec(unreadable_address(), 1..=MOST_PROJECTS),
    ) {
        let project = project_at(&unreadable_addresses);

        let loaded_project = load_project(&state_with(&project), &project);

        prop_assert_eq!(
            list_addresses(&loaded_project.repositories),
            unreadable_addresses
        );
    }
}
