use axum::http::{Method, StatusCode};
use orchestration_api::accounts::{
    AccountView, CreateAccountRequest, DeviceRegistration, PairingRequestView,
};
use orchestration_api::routes::{ACCOUNTS, PAIRING_SESSIONS};
use orchestration_core::device::{Device, DeviceKind, DeviceRole};
use orchestration_core::identifiers::WorkspaceId;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{
    OWNER_SEED, account_request_for, create_account, identity_from_seed,
    registration_for,
};
use crate::pairing_fixtures::{approve_session, join_session, start_pairing};
use crate::test_client::{TestServer, block_on, encode_json};

const KIND_CASES: u32 = 4;
const JOINER_SEED: u8 = 17;
const JOINER_NAME: &str = "pocket-phone";

fn kind_strategy() -> impl Strategy<Value = DeviceKind> {
    prop_oneof![Just(DeviceKind::Computer), Just(DeviceKind::Phone)]
}

fn account_request_of_kind(
    test: &TestServer,
    kind: DeviceKind,
) -> CreateAccountRequest {
    let owner = identity_from_seed(OWNER_SEED);
    let workspace_id = WorkspaceId(Uuid::new_v4());
    let request =
        account_request_for(&owner, workspace_id, test.read_setup_code());
    let device = DeviceRegistration {
        kind,
        ..request.device
    };
    CreateAccountRequest { device, ..request }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(KIND_CASES))]

    #[test]
    fn test_register_device_property_keeps_the_kind_of_a_new_account(
        kind in kind_strategy(),
    ) {
        let test = TestServer::start();
        let request = account_request_of_kind(&test, kind);

        let response = block_on(test.send_unsigned(
            Method::POST,
            ACCOUNTS,
            encode_json(&request),
        ));

        prop_assert_eq!(response.status, StatusCode::CREATED);
        let account: AccountView = response.json();
        prop_assert_eq!(account.device.kind, kind);
    }

    #[test]
    fn test_pairing_property_keeps_the_kind_of_the_joining_device(
        kind in kind_strategy(),
    ) {
        let test = TestServer::start();
        let (joining_kind, paired) = block_on(async {
            let account = create_account(&test).await;
            let joiner = identity_from_seed(JOINER_SEED);
            let registration = DeviceRegistration {
                kind,
                ..registration_for(&joiner, JOINER_NAME, DeviceRole::Client)
            };
            let session = start_pairing(&test, &account).await;
            join_session(&test, &session.code, registration.clone()).await;
            let view_path = format!("{PAIRING_SESSIONS}/{}", session.code);
            let view: PairingRequestView =
                test.get(&account.owner, &view_path).await.json();
            let approved =
                approve_session(&test, &account, &session.code, &registration)
                    .await;
            let paired: Device = approved.json();
            (view.joining.map(|joining| joining.kind), paired)
        });

        prop_assert_eq!(joining_kind, Some(kind));
        prop_assert_eq!(paired.kind, kind);
    }
}
