use orchestration_api::routes::{
    PAIRING_SESSION, PROJECT_REPOSITORIES, WORKSPACE_DEVICE,
};
use orchestration_node::server_client::{encode_path_segment, fill_route};
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

    #[test]
    fn test_encode_path_segment_property_keeps_one_reversible_segment(
        step_name in "\\PC{0,40}",
    ) {
        let encoded = encode_path_segment(&step_name);

        let is_one_segment = encoded.chars().all(|character| {
            character.is_ascii_alphanumeric()
                || character == '-'
                || character == '%'
        });
        prop_assert!(is_one_segment, "{}", encoded);
        let mut decoded_bytes = Vec::new();
        let mut remaining = encoded.as_str();
        while let Some(character) = remaining.chars().next() {
            if character == '%' {
                let byte = u8::from_str_radix(&remaining[1..3], 16)?;
                decoded_bytes.push(byte);
                remaining = &remaining[3..];
            } else {
                decoded_bytes.push(u8::try_from(character)?);
                remaining = &remaining[1..];
            }
        }
        prop_assert_eq!(String::from_utf8(decoded_bytes)?, step_name);
    }
}
