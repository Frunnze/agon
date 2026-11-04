use orchestration_api::routes::{SERVER_GROUP, SERVER_GROUP_MEMBERS};
use orchestration_api::server_group::{ReplicaCopy, ServerGroupView};
use orchestration_core::device::DeviceRole;
use proptest::prelude::*;

use crate::fixtures::{OWNER_SEED, identity_from_seed, pair_device};
use crate::server_group_fixtures::{replica_path, start_group};
use crate::test_client::{TestServer, block_on};

const COPY_CASES: u32 = 4;
const OTHER_CLIENT_SEED: u8 = 61;

fn read_group(test: &TestServer) -> ServerGroupView {
    let reader = identity_from_seed(OWNER_SEED);
    block_on(test.get(&reader, SERVER_GROUP)).json()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COPY_CASES))]

    #[test]
    fn test_describe_group_property_lists_the_latest_copy_request(
        first_after in any::<u64>(),
        latest_after in any::<u64>(),
    ) {
        let fixture = block_on(start_group());
        let backup_device = &fixture.backup_device;
        let first_path = replica_path(first_after);
        let latest_path = replica_path(latest_after);

        block_on(fixture.active.get(backup_device, &first_path));
        block_on(fixture.active.get(backup_device, &latest_path));
        let view = read_group(&fixture.active);

        let expected_copy = ReplicaCopy {
            device_id: backup_device.device_id(),
            verified_revision: latest_after,
            verified_at: fixture.active.now(),
        };
        prop_assert_eq!(view.copies, vec![expected_copy]);
    }

    #[test]
    fn test_fetch_replica_property_records_nothing_for_a_non_member(
        after in any::<u64>(),
    ) {
        let fixture = block_on(start_group());
        let other = identity_from_seed(OTHER_CLIENT_SEED);
        block_on(pair_device(
            &fixture.active,
            &fixture.account,
            &other,
            "other-mac",
            DeviceRole::Client,
        ));

        block_on(fixture.active.get(&other, &replica_path(after)));
        let view = read_group(&fixture.active);

        prop_assert!(view.copies.is_empty());
    }
}

#[test]
fn test_describe_group_property_drops_the_copy_of_a_member_that_left() {
    let fixture = block_on(start_group());
    let backup_device = &fixture.backup_device;
    let backup_id = backup_device.device_id().0;
    let member_path = format!("{SERVER_GROUP_MEMBERS}/{backup_id}");

    block_on(fixture.active.get(backup_device, &replica_path(0)));
    block_on(fixture.active.delete(backup_device, &member_path));
    let view = read_group(&fixture.active);

    assert_eq!(view.copies, Vec::new());
}
