use std::net::SocketAddr;

use axum::http::StatusCode;
use orchestration_api::accounts::PublishPeerAddressRequest;
use orchestration_api::work::RunEvent;
use orchestration_core::device::{Device, DeviceRole, RunnerLink};
use orchestration_core::peer_address::PeerAddress;
use orchestration_security::peer_addresses::sign_peer_address;
use proptest::prelude::*;

use crate::fixtures::{create_account, identity_from_seed, pair_device};
use crate::run_fixtures::{post_events, start_claimed_run};
use crate::test_client::{TestServer, block_on};

const PEER_ADDRESS_PATH: &str = "/devices/peer-address";
const RUNNER_SEED: u8 = 61;

fn sample_address(key: [u8; 32], port: u16) -> PeerAddress {
    PeerAddress {
        endpoint_public_key: key,
        direct_addresses: vec![SocketAddr::from(([127, 0, 0, 1], port))],
        relay_url: None,
    }
}

fn link_changed(link: RunnerLink) -> RunEvent {
    RunEvent::LinkChanged { link }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_publish_peer_address_property_stores_signed_addresses(
        key in any::<[u8; 32]>(),
        port in 1_u16..,
    ) {
        let test = TestServer::start();
        let (status, devices) = block_on(async {
            let account = create_account(&test).await;
            let runner = identity_from_seed(RUNNER_SEED);
            let role = DeviceRole::Runner;
            pair_device(&test, &account, &runner, "office", role).await;
            let address = sample_address(key, port);
            let signed = sign_peer_address(&runner, &address, test.now());
            let request = PublishPeerAddressRequest { address: signed };
            let path = PEER_ADDRESS_PATH;
            let published = test.put(&runner, path, &request).await;
            let devices: Vec<Device> =
                test.get(&account.owner, "/devices").await.json();
            (published.status, devices)
        });

        prop_assert_eq!(status, StatusCode::OK);
        let runner_id = identity_from_seed(RUNNER_SEED).device_id();
        let runner = devices.iter().find(|device| device.id == runner_id);
        let stored = runner.and_then(|device| device.peer_address.clone());
        let stored_key =
            stored.map(|signed| signed.address.endpoint_public_key);
        prop_assert_eq!(stored_key, Some(key));
    }

    #[test]
    fn test_publish_peer_address_property_rejects_forged_signatures(
        key in any::<[u8; 32]>(),
        forged_signature in proptest::collection::vec(any::<u8>(), 0..80),
    ) {
        let test = TestServer::start();
        let (status, stored) = block_on(async {
            let account = create_account(&test).await;
            let address = sample_address(key, 4000);
            let mut signed =
                sign_peer_address(&account.owner, &address, test.now());
            signed.signature = forged_signature;
            let request = PublishPeerAddressRequest { address: signed };
            let published =
                test.put(&account.owner, PEER_ADDRESS_PATH, &request).await;
            let devices: Vec<Device> =
                test.get(&account.owner, "/devices").await.json();
            let stored: Vec<bool> = devices
                .iter()
                .map(|device| device.peer_address.is_some())
                .collect();
            (published.status, stored)
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert!(stored.iter().all(|has_address| !has_address));
    }
}

#[test]
fn a_device_cannot_publish_an_address_signed_by_another_device() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let runner = identity_from_seed(RUNNER_SEED);
        let role = DeviceRole::Runner;
        pair_device(&test, &account, &runner, "office", role).await;
        let address = sample_address([5; 32], 4000);
        let signed = sign_peer_address(&account.owner, &address, test.now());
        let request = PublishPeerAddressRequest { address: signed };
        test.put(&runner, PEER_ADDRESS_PATH, &request).await.status
    });

    assert_eq!(status, StatusCode::FORBIDDEN);
}

#[test]
fn a_dropped_link_records_when_it_was_lost() {
    let test = TestServer::start();
    let (connected, dropped, reconnected) = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let holder = &claimed.holder;
        let run = &claimed.run;
        let direct = vec![link_changed(RunnerLink::Direct)];
        let (_, connected) = post_events(&test, holder, run, direct).await;
        let unreachable = vec![link_changed(RunnerLink::Unreachable)];
        let (_, dropped) = post_events(&test, holder, run, unreachable).await;
        let relay = vec![link_changed(RunnerLink::Relay)];
        let (_, reconnected) = post_events(&test, holder, run, relay).await;
        (connected, dropped, reconnected)
    });

    let connected = connected.expect("the link change is stored");
    let dropped = dropped.expect("the link loss is stored");
    let reconnected = reconnected.expect("the new link is stored");
    assert_eq!(connected.link, RunnerLink::Direct);
    assert_eq!(connected.link_lost_at, None);
    assert_eq!(dropped.link, RunnerLink::Unreachable);
    assert_eq!(dropped.link_lost_at, Some(test.now()));
    assert_eq!(reconnected.link, RunnerLink::Relay);
    assert_eq!(reconnected.link_lost_at, None);
}
