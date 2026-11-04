#![allow(clippy::expect_used)]

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_api::server_group::{ReplicaCopy, ServerGroupView};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{ServerGroup, ServerStanding};
use proptest::collection::vec;
use proptest::prelude::*;

const MOST_COPIES: usize = 4;
const LATEST_SECOND: i64 = 4_000_000_000;

fn copy_strategy() -> impl Strategy<Value = ReplicaCopy> {
    ("[0-9a-f]{8}", any::<u64>(), 0..LATEST_SECOND).prop_map(
        |(device_text, verified_revision, seconds)| ReplicaCopy {
            device_id: DeviceId(device_text),
            verified_revision,
            verified_at: DateTime::<Utc>::UNIX_EPOCH
                + TimeDelta::seconds(seconds),
        },
    )
}

proptest! {
    #[test]
    fn test_server_group_view_property_survives_json_round_trip(
        revision in any::<u64>(),
        copies in vec(copy_strategy(), 0..MOST_COPIES),
    ) {
        let view = ServerGroupView {
            group: ServerGroup::default(),
            standing: ServerStanding::Active,
            revision,
            copies,
        };
        let encoded_view =
            serde_json::to_string(&view).expect("the view encodes as JSON");
        let decoded_view: ServerGroupView =
            serde_json::from_str(&encoded_view)
                .expect("the view decodes from JSON");

        prop_assert_eq!(decoded_view, view);
    }

    #[test]
    fn test_server_group_view_property_reads_older_views_without_copies(
        revision in any::<u64>(),
    ) {
        let older_view = serde_json::json!({
            "group": ServerGroup::default(),
            "standing": "backup",
            "revision": revision,
        });

        let decoded_view: ServerGroupView =
            serde_json::from_value(older_view)
                .expect("an older view decodes");

        prop_assert_eq!(decoded_view.revision, revision);
        prop_assert!(decoded_view.copies.is_empty());
    }
}
