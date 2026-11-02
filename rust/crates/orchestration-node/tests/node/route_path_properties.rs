use orchestration_api::routes::{
    PAIRING_SESSION, PROJECT_REPOSITORIES, WORKSPACE_DEVICE,
};
use orchestration_node::server_client::fill_route;
use proptest::prelude::*;

use crate::support::test_device::fail;

const SAFE_VALUE_PATTERN: &str = "[A-Za-z0-9-]{1,40}";

proptest! {
    #[test]
    fn test_fill_route_property_replaces_every_placeholder(
        workspace_value in SAFE_VALUE_PATTERN,
        device_value in SAFE_VALUE_PATTERN,
    ) {
        let filled_path = fill_route(
            WORKSPACE_DEVICE,
            &[
                ("workspace_id", &workspace_value),
                ("device_id", &device_value),
            ],
        )
        .map_err(fail)?;

        prop_assert_eq!(
            filled_path,
            format!("/workspaces/{workspace_value}/devices/{device_value}")
        );
    }

    #[test]
    fn test_fill_route_property_rejects_values_outside_a_path_segment(
        prefix in "[a-z0-9]{0,8}",
        unsafe_character in "[/?#%. {}&=]",
        suffix in "[a-z0-9]{0,8}",
    ) {
        let unsafe_value = format!("{prefix}{unsafe_character}{suffix}");

        let filled_path =
            fill_route(PAIRING_SESSION, &[("code", &unsafe_value)]);

        prop_assert!(filled_path.is_err());
    }

    #[test]
    fn test_fill_route_property_rejects_a_missing_placeholder_value(
        project_value in SAFE_VALUE_PATTERN,
    ) {
        let filled_path =
            fill_route(PROJECT_REPOSITORIES, &[("other_id", &project_value)]);

        prop_assert!(filled_path.is_err());
    }

    #[test]
    fn test_fill_route_property_arbitrary_values_never_panic(
        arbitrary_value in "\\PC{0,40}",
    ) {
        let filled_path =
            fill_route(PAIRING_SESSION, &[("code", &arbitrary_value)]);

        let is_safe = !arbitrary_value.is_empty()
            && arbitrary_value
                .chars()
                .all(|character| character.is_ascii_alphanumeric()
                    || character == '-');
        prop_assert_eq!(filled_path.is_ok(), is_safe);
    }
}
