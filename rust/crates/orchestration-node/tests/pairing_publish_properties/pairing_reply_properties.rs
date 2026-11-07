use std::collections::BTreeSet;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::pairing_desk::{
    BareDevice, LocalAppServer, PUBLISH_CASES, PairingDevice,
    RENDEZVOUS_PROBLEM_FIELD, fail, peer_relay_choices, start_pairing,
};

const LARGEST_START_COUNT: usize = 3;
const PAIRING_REQUEST_FIELDS: [&str; 5] = [
    "code",
    "display_code",
    "started_at",
    "expires_at",
    "joining",
];

fn list_field_names(reply: &Value) -> BTreeSet<String> {
    let mut field_names = BTreeSet::new();
    if let Some(fields) = reply.as_object() {
        for field_name in fields.keys() {
            field_names.insert(field_name.clone());
        }
    }
    field_names
}

fn list_expected_field_names(extra_fields: &[&str]) -> BTreeSet<String> {
    let mut field_names = BTreeSet::new();
    for field_name in PAIRING_REQUEST_FIELDS.iter().chain(extra_fields) {
        field_names.insert((*field_name).to_owned());
    }
    field_names
}

fn read_pairing_request(
    device: &dyn PairingDevice,
    session: &Value,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "pairing_request",
        "code": session["code"],
    }))
}

fn remove_rendezvous_problem(session: &Value) -> Value {
    let mut request_part = session.clone();
    if let Some(fields) = request_part.as_object_mut() {
        fields.remove(RENDEZVOUS_PROBLEM_FIELD);
    }
    request_part
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PUBLISH_CASES))]

    #[test]
    fn test_start_pairing_property_the_reply_keeps_every_pairing_field(
        peer_relay in peer_relay_choices(),
        start_count in 1..=LARGEST_START_COUNT,
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device = BareDevice::open_with_account(&server, peer_relay)
            .map_err(fail)?;
        let expected_fields =
            list_expected_field_names(&[RENDEZVOUS_PROBLEM_FIELD]);

        for _ in 0..start_count {
            let session = start_pairing(&device).map_err(fail)?;
            let session_fields = list_field_names(&session);

            prop_assert_eq!(&session_fields, &expected_fields);
            prop_assert_eq!(&session["joining"], &Value::Null);
        }
    }

    #[test]
    fn test_read_pairing_request_property_names_no_rendezvous_problem(
        peer_relay in peer_relay_choices(),
        start_count in 1..=LARGEST_START_COUNT,
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device = BareDevice::open_with_account(&server, peer_relay)
            .map_err(fail)?;
        let expected_fields = list_expected_field_names(&[]);

        for _ in 0..start_count {
            let session = start_pairing(&device).map_err(fail)?;
            let request =
                read_pairing_request(&device, &session).map_err(fail)?;
            let request_fields = list_field_names(&request);

            prop_assert_eq!(&request_fields, &expected_fields);
        }
    }

    #[test]
    fn test_start_pairing_property_the_reply_shows_the_requested_session(
        peer_relay in peer_relay_choices(),
        start_count in 1..=LARGEST_START_COUNT,
    ) {
        let server = LocalAppServer::start().map_err(fail)?;
        let device = BareDevice::open_with_account(&server, peer_relay)
            .map_err(fail)?;

        for _ in 0..start_count {
            let session = start_pairing(&device).map_err(fail)?;
            let request = read_pairing_request(&device, &session);

            prop_assert_eq!(request, Ok(remove_rendezvous_problem(&session)));
        }
    }
}
