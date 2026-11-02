use orchestration_node::device_files::{DeviceFiles, PendingJoin};
use orchestration_security::pairing::PairingPublicKeys;
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;
use uuid::Uuid;

use crate::support::test_device::fail;

const LONGEST_FIELD: usize = 48;
const DISPLAY_CODE_PATTERN: &str = "[0-9A-Z]{3}-[0-9A-Z]{3}";

fn bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_FIELD)
}

fn pending_join_strategy() -> impl Strategy<Value = PendingJoin> {
    (
        any::<u128>(),
        DISPLAY_CODE_PATTERN,
        bytes_strategy(),
        bytes_strategy(),
        bytes_strategy(),
        bytes_strategy(),
    )
        .prop_map(
            |(number, display_code, nonce, signing, sealing, commitment)| {
                PendingJoin {
                    join_id: Uuid::from_u128(number),
                    display_code,
                    joiner_nonce: nonce,
                    approver: PairingPublicKeys {
                        signing_public_key: signing,
                        sealing_public_key: sealing,
                    },
                    approver_commitment: commitment,
                }
            },
        )
}

proptest! {
    #[test]
    fn test_view_property_shows_only_the_join_and_its_code(
        pending_join in pending_join_strategy(),
    ) {
        let view = pending_join.view();

        let shown = serde_json::to_value(&view).map_err(fail)?;

        prop_assert_eq!(view.join_id, pending_join.join_id);
        prop_assert_eq!(&view.display_code, &pending_join.display_code);
        let shown_fields = shown.as_object().map(serde_json::Map::len);
        prop_assert_eq!(shown_fields, Some(2));
    }

    #[test]
    fn test_save_pending_join_property_loads_back_the_exchange(
        pending_join in pending_join_strategy(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let files = DeviceFiles::open(directory.path()).map_err(fail)?;

        files.save_pending_join(&pending_join).map_err(fail)?;
        let loaded = files.load_pending_join().map_err(fail)?;

        prop_assert_eq!(loaded, Some(pending_join));
    }
}
