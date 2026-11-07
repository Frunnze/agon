use orchestration_core::identifiers::ProjectId;
use orchestration_server::{Server, StoredState};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::fixtures::{create_project, identity_from_seed};
use crate::old_stored_addresses::{
    distinct_old_addresses, list_addresses, list_canonical_addresses,
    list_stored_addresses, local_address, replace_repositories,
};
use crate::server_group_fixtures::{
    BACKUP_SEED, GroupFixture, fetch_replica_bytes, start_group,
};
use crate::test_client::block_on;

const REPLICA_CASES: u32 = 6;
const FIRST_REVISION: u64 = 0;
const MOST_FOLDERS: usize = 3;

fn old_replica_bytes(
    fixture: &GroupFixture,
    project_id: ProjectId,
    stored_addresses: &[String],
) -> Vec<u8> {
    let replica_bytes = block_on(fetch_replica_bytes(
        &fixture.active,
        &fixture.backup_device,
        FIRST_REVISION,
    ));
    let active_state: StoredState =
        serde_json::from_slice(&replica_bytes).expect("the copy decodes");
    let old_state =
        replace_repositories(&active_state, project_id, stored_addresses);
    serde_json::to_vec(&old_state).expect("the old copy encodes")
}

fn install_old_copy(stored_addresses: &[String]) -> Vec<String> {
    let fixture = block_on(start_group());
    let project = block_on(create_project(&fixture.active, &fixture.account));
    let replica_bytes =
        old_replica_bytes(&fixture, project.id, stored_addresses);
    let source_id = fixture.active.server.device_id();

    fixture
        .backup
        .server
        .install_replica(&replica_bytes, &source_id)
        .expect("the old copy installs");

    let installed_state = fixture
        .backup
        .server
        .snapshot_state()
        .expect("the backup state is readable");
    list_addresses(&installed_state.projects[&project.id].repositories)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPLICA_CASES))]

    #[test]
    fn test_parse_replica_property_installs_old_addresses_in_canonical_form(
        old_addresses in distinct_old_addresses(),
    ) {
        let stored_addresses = list_stored_addresses(&old_addresses);

        let installed_addresses = install_old_copy(&stored_addresses);

        prop_assert_eq!(
            installed_addresses,
            list_canonical_addresses(&old_addresses)
        );
    }

    #[test]
    fn test_parse_replica_property_keeps_local_folders_untouched(
        local_addresses in vec(
            local_address(&identity_from_seed(BACKUP_SEED).device_id()),
            1..=MOST_FOLDERS,
        ),
    ) {
        let installed_addresses = install_old_copy(&local_addresses);

        prop_assert_eq!(installed_addresses, local_addresses);
    }

    #[test]
    fn test_parse_replica_property_seeded_copy_opens_in_canonical_form(
        old_addresses in distinct_old_addresses(),
    ) {
        let fixture = block_on(start_group());
        let project =
            block_on(create_project(&fixture.active, &fixture.account));
        let stored_addresses = list_stored_addresses(&old_addresses);
        let replica_bytes =
            old_replica_bytes(&fixture, project.id, &stored_addresses);
        let source_id = fixture.active.server.device_id();

        Server::seed_replica(
            fixture.backup.directory.path(),
            &replica_bytes,
            &source_id,
        )
        .expect("the old copy seeds");
        let reopened_state = fixture
            .backup
            .restart()
            .server
            .snapshot_state()
            .expect("the reopened state is readable");

        prop_assert_eq!(
            list_addresses(&reopened_state.projects[&project.id].repositories),
            list_canonical_addresses(&old_addresses)
        );
    }
}
