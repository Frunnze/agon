use orchestration_api::routes::PROJECTS;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::workspace::Project;
use proptest::prelude::*;

use crate::fixtures::{Account, create_account, create_project};
use crate::old_stored_addresses::{
    OldAddress, distinct_old_addresses, list_addresses,
    list_canonical_addresses, list_stored_addresses,
    restart_with_stored_addresses,
};
use crate::test_client::{TestServer, block_on};

const LISTING_CASES: u32 = 8;

async fn list_project_addresses(
    test: &TestServer,
    account: &Account,
) -> Vec<String> {
    let projects: Vec<Project> =
        test.get(&account.owner, PROJECTS).await.json();
    let mut addresses = Vec::new();
    for project in &projects {
        addresses.extend(list_addresses(&project.repositories));
    }
    addresses
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
        list_project_addresses(&restarted, &account).await
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LISTING_CASES))]

    #[test]
    fn test_list_projects_property_lists_old_addresses_in_canonical_form(
        old_addresses in distinct_old_addresses(),
    ) {
        let listed_addresses = list_after_restart(&old_addresses);

        prop_assert_eq!(
            listed_addresses,
            list_canonical_addresses(&old_addresses)
        );
    }

    #[test]
    fn test_list_projects_property_listed_addresses_reparse_to_themselves(
        old_addresses in distinct_old_addresses(),
    ) {
        let listed_addresses = list_after_restart(&old_addresses);

        prop_assert_eq!(listed_addresses.len(), old_addresses.len());
        for address in listed_addresses {
            prop_assert_eq!(parse_repository_address(&address), Ok(address));
        }
    }

    #[test]
    fn test_list_projects_property_a_second_restart_lists_the_same(
        old_addresses in distinct_old_addresses(),
    ) {
        let test = TestServer::start();
        let (first_listing, second_listing) = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let stored_addresses = list_stored_addresses(&old_addresses);
            let restarted = restart_with_stored_addresses(
                &test,
                project.id,
                &stored_addresses,
            );
            let first_listing =
                list_project_addresses(&restarted, &account).await;
            let restarted_again = restarted.restart();
            let second_listing =
                list_project_addresses(&restarted_again, &account).await;
            (first_listing, second_listing)
        });

        prop_assert_eq!(&first_listing, &second_listing);
        let canonical_addresses = list_canonical_addresses(&old_addresses);
        prop_assert_eq!(first_listing, canonical_addresses);
    }
}
