use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use orchestration_api::routes::PROJECTS;
use orchestration_core::identifiers::{DeviceId, ProjectId, WorkspaceId};
use orchestration_core::local_folders::LOCAL_ADDRESS_PREFIX;
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use orchestration_server::{StateStorage, StoredState};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::address_strategies::{GIT_SUFFIX, canonical_address};
use crate::test_client::TestServer;

const PROJECT_NAME: &str = "old-project";
const SUPPORTED_SCHEME: &str = "https";
const SECURE_SHELL_PREFIX: &str = "git@";
const MOST_GIT_SUFFIXES: usize = 4;
const MOST_CASE_CHOICES: usize = 12;
const MOST_REPOSITORIES: usize = 4;
const FOLDER_PATH: &str = "(/[A-Za-z0-9_-]{1,8}){1,4}/?";
const BRANCH_NAME: &str = "[a-z][a-z0-9-]{0,10}";
const DEFAULT_BRANCH: &str = "main";

#[derive(Clone, Debug)]
pub struct OldAddress {
    pub canonical_address: String,
    pub stored_address: String,
}

#[derive(Clone, Debug)]
enum AddressPrefix {
    Bare,
    Https { scheme: String },
    SecureShell,
}

fn scramble_letter_case(text: &str, uppercase_choices: &[bool]) -> String {
    let mut scrambled = String::new();
    let choices = uppercase_choices.iter().cycle();
    for (character, is_uppercase) in text.chars().zip(choices) {
        if *is_uppercase {
            scrambled.push(character.to_ascii_uppercase());
        } else {
            scrambled.push(character);
        }
    }
    scrambled
}

fn case_choices() -> impl Strategy<Value = Vec<bool>> {
    vec(any::<bool>(), 1..MOST_CASE_CHOICES)
}

fn address_prefix() -> impl Strategy<Value = AddressPrefix> {
    let https = case_choices().prop_map(|uppercase_choices| {
        let scheme =
            scramble_letter_case(SUPPORTED_SCHEME, &uppercase_choices);
        AddressPrefix::Https { scheme }
    });
    prop_oneof![
        Just(AddressPrefix::Bare),
        https,
        Just(AddressPrefix::SecureShell),
    ]
}

fn spell_old_address(
    canonical_address: &str,
    prefix: &AddressPrefix,
    uppercase_choices: &[bool],
    git_suffix_count: usize,
) -> String {
    let (host, owner_and_name) = canonical_address
        .split_once('/')
        .expect("a canonical address starts with its host");
    let stored_host = scramble_letter_case(host, uppercase_choices);
    let git_suffixes = GIT_SUFFIX.repeat(git_suffix_count);
    match prefix {
        AddressPrefix::Bare => {
            format!("{stored_host}/{owner_and_name}{git_suffixes}")
        }
        AddressPrefix::Https { scheme } => {
            format!("{scheme}://{stored_host}/{owner_and_name}{git_suffixes}/")
        }
        AddressPrefix::SecureShell => format!(
            "{SECURE_SHELL_PREFIX}{stored_host}:{owner_and_name}{git_suffixes}"
        ),
    }
}

fn old_spelling_of(
    canonical_address: String,
) -> impl Strategy<Value = OldAddress> {
    (address_prefix(), case_choices(), 1..=MOST_GIT_SUFFIXES).prop_map(
        move |(prefix, uppercase_choices, suffix_count)| {
            let stored_address = spell_old_address(
                &canonical_address,
                &prefix,
                &uppercase_choices,
                suffix_count,
            );
            OldAddress {
                canonical_address: canonical_address.clone(),
                stored_address,
            }
        },
    )
}

pub fn old_address() -> impl Strategy<Value = OldAddress> {
    canonical_address().prop_flat_map(old_spelling_of)
}

pub fn two_old_spellings_of_one_repository()
-> impl Strategy<Value = (OldAddress, OldAddress)> {
    canonical_address().prop_flat_map(|canonical_address| {
        let first_spelling = old_spelling_of(canonical_address.clone());
        let second_spelling = old_spelling_of(canonical_address);
        (first_spelling, second_spelling)
    })
}

fn has_distinct_repositories(old_addresses: &[OldAddress]) -> bool {
    let mut canonical_addresses = BTreeSet::new();
    for old_address in old_addresses {
        canonical_addresses.insert(old_address.canonical_address.as_str());
    }
    canonical_addresses.len() == old_addresses.len()
}

pub fn distinct_old_addresses() -> impl Strategy<Value = Vec<OldAddress>> {
    vec(old_address(), 1..=MOST_REPOSITORIES)
        .prop_filter("each repository is listed once", |old_addresses| {
            has_distinct_repositories(old_addresses)
        })
}

pub fn local_address(device_id: &DeviceId) -> impl Strategy<Value = String> {
    let device_text = device_id.0.clone();
    FOLDER_PATH.prop_map(move |path| {
        format!("{LOCAL_ADDRESS_PREFIX}{device_text}:{path}")
    })
}

pub fn branch_name() -> impl Strategy<Value = String> {
    BRANCH_NAME
}

fn repository_at(address: &str) -> Repository {
    Repository {
        address: address.to_owned(),
        default_branch: DEFAULT_BRANCH.to_owned(),
        agent_access: AgentAccess::ReadOnly,
    }
}

pub fn list_stored_addresses(old_addresses: &[OldAddress]) -> Vec<String> {
    let mut stored_addresses = Vec::new();
    for old_address in old_addresses {
        stored_addresses.push(old_address.stored_address.clone());
    }
    stored_addresses
}

pub fn list_canonical_addresses(old_addresses: &[OldAddress]) -> Vec<String> {
    let mut canonical_addresses = Vec::new();
    for old_address in old_addresses {
        canonical_addresses.push(old_address.canonical_address.clone());
    }
    canonical_addresses
}

pub fn list_addresses(repositories: &[Repository]) -> Vec<String> {
    let mut addresses = Vec::new();
    for repository in repositories {
        addresses.push(repository.address.clone());
    }
    addresses
}

pub fn project_with(repositories: Vec<Repository>) -> Project {
    Project {
        id: ProjectId(Uuid::new_v4()),
        workspace_id: WorkspaceId(Uuid::new_v4()),
        name: PROJECT_NAME.to_owned(),
        repositories,
        approval_policy: None,
    }
}

pub fn state_with(project: &Project) -> StoredState {
    let mut projects = BTreeMap::new();
    projects.insert(project.id, project.clone());
    StoredState {
        projects,
        ..StoredState::default()
    }
}

pub fn store_then_load(directory: &Path, state: &StoredState) -> StoredState {
    let storage = StateStorage::new(directory.to_path_buf());
    storage.save_state(state).expect("the state saves");
    storage.load_state().expect("the state loads")
}

pub fn replace_repositories(
    state: &StoredState,
    project_id: ProjectId,
    stored_addresses: &[String],
) -> StoredState {
    let project = state
        .projects
        .get(&project_id)
        .expect("the project is stored");
    let old_project = Project {
        repositories: repositories_at(stored_addresses),
        ..project.clone()
    };
    let mut projects = state.projects.clone();
    projects.insert(project_id, old_project);
    StoredState {
        projects,
        ..state.clone()
    }
}

pub fn restart_with_stored_addresses(
    test: &TestServer,
    project_id: ProjectId,
    stored_addresses: &[String],
) -> TestServer {
    let state = test.server.snapshot_state().expect("the state is readable");
    let old_state = replace_repositories(&state, project_id, stored_addresses);
    let storage = StateStorage::new(test.directory.path().to_path_buf());
    storage.save_state(&old_state).expect("the old state saves");
    test.restart()
}

pub fn repositories_path(project_id: ProjectId) -> String {
    format!("{PROJECTS}/{}/repositories", project_id.0)
}

fn repositories_at(addresses: &[String]) -> Vec<Repository> {
    let mut repositories = Vec::new();
    for address in addresses {
        repositories.push(repository_at(address));
    }
    repositories
}

pub fn project_at(addresses: &[String]) -> Project {
    project_with(repositories_at(addresses))
}
