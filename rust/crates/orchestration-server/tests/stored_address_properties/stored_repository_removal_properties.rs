use axum::http::StatusCode;
use orchestration_api::catalog::RemoveRepositoryRequest;
use orchestration_api::routes::PROJECTS;
use orchestration_core::workspace::Project;
use proptest::prelude::*;

use crate::fixtures::{create_account, create_project};
use crate::old_stored_addresses::{
    OldAddress, distinct_old_addresses, list_addresses,
    list_canonical_addresses, list_stored_addresses, repositories_path,
    restart_with_stored_addresses,
};
use crate::test_client::{TestServer, block_on};

const REMOVAL_CASES: u32 = 8;

#[derive(Debug)]
struct Removal {
    status: StatusCode,
    remaining_addresses: Option<Vec<String>>,
    listed_after_restart: Vec<String>,
}

fn remove_after_restart(
    old_addresses: &[OldAddress],
    requested_address: &str,
) -> Removal {
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
        let request = RemoveRepositoryRequest {
            address: requested_address.to_owned(),
        };
        let path = repositories_path(project.id);

        let response = restarted
            .delete_with_body(&account.owner, &path, &request)
            .await;

        let is_removed = response.status == StatusCode::OK;
        let remaining_addresses = is_removed.then(|| {
            let changed_project: Project = response.json();
            list_addresses(&changed_project.repositories)
        });
        let reopened = restarted.restart();
        let projects: Vec<Project> =
            reopened.get(&account.owner, PROJECTS).await.json();
        let listed_after_restart = list_addresses(&projects[0].repositories);
        Removal {
            status: response.status,
            remaining_addresses,
            listed_after_restart,
        }
    })
}

fn expected_remaining(
    old_addresses: &[OldAddress],
    removed_index: usize,
) -> Vec<String> {
    let mut canonical_addresses = list_canonical_addresses(old_addresses);
    canonical_addresses.remove(removed_index);
    canonical_addresses
}

fn old_addresses_and_index() -> impl Strategy<Value = (Vec<OldAddress>, usize)>
{
    distinct_old_addresses().prop_flat_map(|old_addresses| {
        let repository_count = old_addresses.len();
        (Just(old_addresses), 0..repository_count)
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REMOVAL_CASES))]

    #[test]
    fn test_remove_repository_property_finds_an_old_address_by_canonical_form(
        (old_addresses, removed_index) in old_addresses_and_index(),
    ) {
        let canonical_address =
            old_addresses[removed_index].canonical_address.clone();

        let removal =
            remove_after_restart(&old_addresses, &canonical_address);

        prop_assert_eq!(removal.status, StatusCode::OK);
        prop_assert_eq!(
            removal.remaining_addresses,
            Some(expected_remaining(&old_addresses, removed_index))
        );
    }

    #[test]
    fn test_remove_repository_property_finds_an_old_address_by_stored_spelling(
        (old_addresses, removed_index) in old_addresses_and_index(),
    ) {
        let stored_address =
            old_addresses[removed_index].stored_address.clone();

        let removal =
            remove_after_restart(&old_addresses, &stored_address);

        prop_assert_eq!(removal.status, StatusCode::OK);
        prop_assert_eq!(
            removal.remaining_addresses,
            Some(expected_remaining(&old_addresses, removed_index))
        );
    }

    #[test]
    fn test_remove_repository_property_removal_survives_a_restart(
        (old_addresses, removed_index) in old_addresses_and_index(),
    ) {
        let canonical_address =
            old_addresses[removed_index].canonical_address.clone();

        let removal =
            remove_after_restart(&old_addresses, &canonical_address);

        prop_assert_eq!(removal.status, StatusCode::OK);
        prop_assert_eq!(
            removal.listed_after_restart,
            expected_remaining(&old_addresses, removed_index)
        );
    }
}
