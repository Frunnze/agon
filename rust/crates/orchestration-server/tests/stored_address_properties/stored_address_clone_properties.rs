use orchestration_api::routes::PROJECTS;
use orchestration_core::workspace::Project;
use orchestration_hub::clone_source::CloneSource;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::fixtures::{create_account, create_project};
use crate::old_stored_addresses::{
    OldAddress, distinct_old_addresses, list_addresses, list_stored_addresses,
    project_at, restart_with_stored_addresses, state_with, store_then_load,
    two_old_spellings_of_one_repository,
};
use crate::test_client::{TestServer, block_on};

const CLONE_CASES: u32 = 8;

fn load_project_addresses(project: &Project) -> Vec<String> {
    let directory = TempDir::new().expect("a directory exists");
    let loaded_state = store_then_load(directory.path(), &state_with(project));
    list_addresses(&loaded_state.projects[&project.id].repositories)
}

fn list_after_restart(old_addresses: &[OldAddress]) -> Vec<String> {
    let test = TestServer::start();
    block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let stored_addresses = list_stored_addresses(old_addresses);
        let restarted = restart_with_stored_addresses(
            &test,
            project.id,
            &stored_addresses,
        );
        let projects: Vec<Project> =
            restarted.get(&account.owner, PROJECTS).await.json();
        list_addresses(&projects[0].repositories)
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CLONE_CASES))]

    #[test]
    fn test_clone_url_property_accepts_every_listed_old_address(
        old_addresses in distinct_old_addresses(),
    ) {
        let clone_source = CloneSource::standard();

        let listed_addresses = list_after_restart(&old_addresses);

        prop_assert_eq!(listed_addresses.len(), old_addresses.len());
        for address in &listed_addresses {
            prop_assert!(clone_source.clone_url(address).is_ok(), "{address}");
        }
    }

    #[test]
    fn test_clone_url_property_builds_the_canonical_https_url(
        old_addresses in distinct_old_addresses(),
    ) {
        let clone_source = CloneSource::standard();
        let project = project_at(&list_stored_addresses(&old_addresses));

        let loaded_addresses = load_project_addresses(&project);

        for (loaded_address, old_address) in
            loaded_addresses.iter().zip(&old_addresses)
        {
            let expected_url =
                format!("https://{}.git", old_address.canonical_address);
            prop_assert_eq!(
                clone_source.clone_url(loaded_address),
                Ok(expected_url)
            );
        }
    }

    #[test]
    fn test_clone_url_property_two_spellings_of_one_repository_agree(
        (first_spelling, second_spelling) in
            two_old_spellings_of_one_repository(),
    ) {
        let clone_source = CloneSource::standard();
        let first_project = project_at(&[first_spelling.stored_address]);
        let second_project = project_at(&[second_spelling.stored_address]);

        let first_loaded = load_project_addresses(&first_project);
        let second_loaded = load_project_addresses(&second_project);

        prop_assert_eq!(
            clone_source.clone_url(&first_loaded[0]),
            clone_source.clone_url(&second_loaded[0])
        );
        prop_assert!(clone_source.clone_url(&first_loaded[0]).is_ok());
    }
}
