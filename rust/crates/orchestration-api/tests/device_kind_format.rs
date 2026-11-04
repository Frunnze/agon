#![allow(clippy::expect_used)]

use chrono::{DateTime, Utc};
use orchestration_api::accounts::{DeviceRegistration, JoiningDevice};
use orchestration_core::device::{
    Device, DeviceKind, DeviceRole, HardwareKeyKind,
};
use orchestration_core::identifiers::DeviceId;
use proptest::prelude::*;
use serde_json::Value;

fn kind_strategy() -> impl Strategy<Value = DeviceKind> {
    prop_oneof![Just(DeviceKind::Computer), Just(DeviceKind::Phone)]
}

fn device_of_kind(name: String, kind: DeviceKind) -> Device {
    Device {
        id: DeviceId("device-1".to_owned()),
        name,
        role: DeviceRole::Client,
        kind,
        key_kind: HardwareKeyKind::Software,
        signing_public_key: vec![1, 2, 3],
        sealing_public_key: vec![4, 5, 6],
        workspaces: Vec::new(),
        paired_at: DateTime::<Utc>::UNIX_EPOCH,
        approved_by: None,
        last_seen: DateTime::<Utc>::UNIX_EPOCH,
        revoked: false,
        peer_address: None,
    }
}

fn registration_of_kind(name: String, kind: DeviceKind) -> DeviceRegistration {
    DeviceRegistration {
        name,
        role: DeviceRole::Runner,
        kind,
        key_kind: HardwareKeyKind::Software,
        signing_public_key: vec![1, 2, 3],
        sealing_public_key: vec![4, 5, 6],
    }
}

fn without_kind(encodable: &impl serde::Serialize) -> Value {
    let mut encoded =
        serde_json::to_value(encodable).expect("the record encodes as JSON");
    let fields = encoded.as_object_mut().expect("the record is an object");
    fields.remove("kind");
    encoded
}

#[test]
fn test_device_kind_property_uses_snake_case_words() {
    let encoded =
        serde_json::to_string(&[DeviceKind::Computer, DeviceKind::Phone])
            .expect("the kinds encode as JSON");

    assert_eq!(encoded, r#"["computer","phone"]"#);
}

proptest! {
    #[test]
    fn test_device_property_survives_json_round_trip_with_its_kind(
        name in "\\PC{0,30}",
        kind in kind_strategy(),
    ) {
        let device = device_of_kind(name, kind);
        let encoded =
            serde_json::to_string(&device).expect("the device encodes");
        let decoded: Device =
            serde_json::from_str(&encoded).expect("the device decodes");

        prop_assert_eq!(decoded, device);
    }

    #[test]
    fn test_device_property_reads_a_record_without_kind_as_computer(
        name in "\\PC{0,30}",
        kind in kind_strategy(),
    ) {
        let stored_record = without_kind(&device_of_kind(name, kind));

        let decoded: Device = serde_json::from_value(stored_record)
            .expect("a record without kind decodes");

        prop_assert_eq!(decoded.kind, DeviceKind::Computer);
    }

    #[test]
    fn test_device_registration_property_reads_no_kind_as_computer(
        name in "\\PC{0,30}",
        kind in kind_strategy(),
    ) {
        let older_registration =
            without_kind(&registration_of_kind(name, kind));

        let decoded: DeviceRegistration =
            serde_json::from_value(older_registration)
                .expect("a registration without kind decodes");

        prop_assert_eq!(decoded.kind, DeviceKind::Computer);
    }

    #[test]
    fn test_joining_device_property_survives_json_round_trip_with_kind(
        name in "\\PC{0,30}",
        kind in kind_strategy(),
    ) {
        let joining = JoiningDevice {
            name,
            role: DeviceRole::Client,
            kind,
            key_kind: HardwareKeyKind::Software,
            signing_public_key: vec![1, 2, 3],
            sealing_public_key: vec![4, 5, 6],
            joiner_nonce: None,
            approver_nonce: None,
        };
        let encoded =
            serde_json::to_string(&joining).expect("the device encodes");
        let decoded: JoiningDevice =
            serde_json::from_str(&encoded).expect("the device decodes");

        prop_assert_eq!(decoded, joining);
    }
}
