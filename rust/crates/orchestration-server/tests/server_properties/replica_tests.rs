use orchestration_server::{Server, ServerError, StoredState};
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::fixtures::create_project;
use crate::operations::{operation_strategy, perform_operation};
use crate::server_group_fixtures::{
    GroupFixture, copy_to_backup, fetch_replica_bytes, start_group,
};
use crate::test_client::block_on;

const REPLICA_CASES: u32 = 8;
const MOST_OPERATIONS: usize = 6;
const LONGEST_FUZZ_INPUT: usize = 256;
const FIRST_REVISION: u64 = 0;

fn fetch_active_state(fixture: &GroupFixture) -> StoredState {
    let replica_bytes = block_on(fetch_replica_bytes(
        &fixture.active,
        &fixture.backup_device,
        FIRST_REVISION,
    ));
    serde_json::from_slice(&replica_bytes).expect("the copy decodes")
}

fn install_state(
    fixture: &GroupFixture,
    state: &StoredState,
) -> Result<(), ServerError> {
    let replica_bytes = serde_json::to_vec(state).expect("the copy encodes");
    fixture
        .backup
        .server
        .install_replica(&replica_bytes, &fixture.active.server.device_id())
}

fn is_conflict(outcome: &Result<(), ServerError>) -> bool {
    matches!(outcome, Err(ServerError::Conflict(_)))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPLICA_CASES))]

    #[test]
    fn test_install_replica_property_copies_any_operations(
        first_operations in vec(operation_strategy(), 1..MOST_OPERATIONS),
        later_operations in vec(operation_strategy(), 1..MOST_OPERATIONS),
    ) {
        let fixture = block_on(start_group());
        let account = &fixture.account;
        let project = block_on(create_project(&fixture.active, account));
        for operation in &first_operations {
            block_on(perform_operation(
                &fixture.active, account, &project, *operation,
            ));
        }
        let first_copy = block_on(copy_to_backup(&fixture));
        let after_first = fixture.backup.server.snapshot_state()?;
        for operation in &later_operations {
            block_on(perform_operation(
                &fixture.active, account, &project, *operation,
            ));
        }
        block_on(create_project(&fixture.active, account));
        let second_copy = block_on(copy_to_backup(&fixture));

        prop_assert_eq!(first_copy, Ok(()));
        prop_assert!(after_first.revision > FIRST_REVISION);
        prop_assert_eq!(second_copy, Ok(()));
        prop_assert_eq!(
            fixture.backup.server.snapshot_state()?,
            fixture.active.server.snapshot_state()?
        );
    }

    #[test]
    fn test_install_replica_property_refuses_arbitrary_bytes(
        replica_bytes in vec(any::<u8>(), 0..LONGEST_FUZZ_INPUT),
    ) {
        let fixture = block_on(start_group());

        let source_id = fixture.active.server.device_id();
        let installed =
            fixture.backup.server.install_replica(&replica_bytes, &source_id);

        prop_assert!(matches!(installed, Err(ServerError::Invalid(_))));
    }
}

#[test]
fn test_install_replica_property_refuses_rewritten_history() {
    let fixture = block_on(start_group());
    block_on(copy_to_backup(&fixture)).expect("the first copy installs");
    let mut rewritten = fetch_active_state(&fixture);
    rewritten.audit_log[0].event.push_str(" (changed)");
    rewritten.revision += 1;

    let installed = install_state(&fixture, &rewritten);

    assert!(is_conflict(&installed), "{installed:?}");
}

#[test]
fn test_install_replica_property_refuses_a_copy_that_is_not_newer() {
    let fixture = block_on(start_group());
    block_on(copy_to_backup(&fixture)).expect("the first copy installs");
    let same = fetch_active_state(&fixture);

    let installed = install_state(&fixture, &same);

    assert!(is_conflict(&installed), "{installed:?}");
}

#[test]
fn test_install_replica_property_refuses_a_copy_from_another_server() {
    let fixture = block_on(start_group());
    let replica_bytes = serde_json::to_vec(&fetch_active_state(&fixture))
        .expect("the copy encodes");

    let installed = fixture
        .backup
        .server
        .install_replica(&replica_bytes, &fixture.backup.server.device_id());

    assert!(is_conflict(&installed), "{installed:?}");
}

#[test]
fn test_install_replica_property_refuses_a_forged_membership() {
    let fixture = block_on(start_group());
    let mut forged = fetch_active_state(&fixture);
    forged.server_group.members[1].membership.signature[0] ^= 1;

    let installed = install_state(&fixture, &forged);

    assert!(
        matches!(installed, Err(ServerError::Forbidden(_))),
        "{installed:?}"
    );
}

#[test]
fn test_install_replica_property_refuses_writes_on_an_active_server() {
    let fixture = block_on(start_group());
    let state = fetch_active_state(&fixture);
    let replica_bytes = serde_json::to_vec(&state).expect("the copy encodes");

    let installed = fixture
        .active
        .server
        .install_replica(&replica_bytes, &fixture.active.server.device_id());

    assert!(is_conflict(&installed), "{installed:?}");
}

#[test]
fn test_seed_replica_property_writes_a_verified_copy_listing_the_server() {
    let fixture = block_on(start_group());
    let replica_bytes = block_on(fetch_replica_bytes(
        &fixture.active,
        &fixture.backup_device,
        FIRST_REVISION,
    ));
    let source_id = fixture.active.server.device_id();
    let unlisted_directory = TempDir::new().expect("a directory exists");

    let seeded = Server::seed_replica(
        fixture.backup.directory.path(),
        &replica_bytes,
        &source_id,
    );
    let unlisted = Server::seed_replica(
        unlisted_directory.path(),
        &replica_bytes,
        &source_id,
    );
    let reopened = fixture.backup.restart();

    assert_eq!(seeded, Ok(()));
    assert!(is_conflict(&unlisted), "{unlisted:?}");
    assert_eq!(
        reopened.server.snapshot_state(),
        fixture.active.server.snapshot_state()
    );
}
