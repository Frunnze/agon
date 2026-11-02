use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::routes::{SERVER_GROUP_MEMBERS, SERVER_GROUP_REPLICA};
use orchestration_api::server_group::JoinServerGroupRequest;
use orchestration_core::device::DeviceRole;
use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};
use orchestration_core::server_group::{ServerMember, ServerTerm};
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::server_group::{
    ServerKeys, sign_server_membership, sign_server_term,
};
use orchestration_server::ServerError;

use crate::fixtures::{
    Account, create_account, identity_from_seed, pair_device,
};
use crate::test_client::{TestResponse, TestServer};

pub const BACKUP_SEED: u8 = 41;
pub const BACKUP_DEVICE_NAME: &str = "backup-mac";
pub const ACTIVE_ENDPOINT_FILL: u8 = 7;
pub const BACKUP_ENDPOINT_FILL: u8 = 8;
pub const FOUNDING_TERM_NUMBER: u64 = 1;

#[derive(Debug)]
pub struct GroupFixture {
    pub active: TestServer,
    pub account: Account,
    pub backup: TestServer,
    pub backup_device: DeviceIdentity,
}

pub fn address_with_key(fill: u8) -> PeerAddress {
    PeerAddress {
        endpoint_public_key: [fill; ENDPOINT_PUBLIC_KEY_LENGTH],
        direct_addresses: Vec::new(),
        relay_url: None,
    }
}

pub fn member_for(
    device: &DeviceIdentity,
    server: &TestServer,
    endpoint_fill: u8,
    joined_at: DateTime<Utc>,
) -> ServerMember {
    let address = address_with_key(endpoint_fill);
    let server_keys = ServerKeys {
        signing_public_key: server.server.public_identity().signing_public_key,
        endpoint_public_key: address.endpoint_public_key,
    };
    ServerMember {
        membership: sign_server_membership(device, &server_keys, joined_at),
        address,
    }
}

pub fn term_for(
    device: &DeviceIdentity,
    server: &TestServer,
    number: u64,
) -> ServerTerm {
    sign_server_term(device, number, server.server.device_id())
}

pub fn found_group_on(test: &TestServer, account: &Account) -> ServerMember {
    let founder =
        member_for(&account.owner, test, ACTIVE_ENDPOINT_FILL, test.now());
    let term = term_for(&account.owner, test, FOUNDING_TERM_NUMBER);
    test.server
        .found_group(&founder, &term)
        .expect("the owner founds the group");
    founder
}

pub async fn join_group(
    active: &TestServer,
    device: &DeviceIdentity,
    member: ServerMember,
) -> TestResponse {
    let request = JoinServerGroupRequest { member };
    active.put(device, SERVER_GROUP_MEMBERS, &request).await
}

pub async fn start_group() -> GroupFixture {
    let active = TestServer::start();
    let account = create_account(&active).await;
    found_group_on(&active, &account);
    let backup_device = identity_from_seed(BACKUP_SEED);
    pair_device(
        &active,
        &account,
        &backup_device,
        BACKUP_DEVICE_NAME,
        DeviceRole::ClientAndRunner,
    )
    .await;
    let backup = TestServer::start();
    backup.server.step_down().expect("the backup steps down");
    let member = member_for(
        &backup_device,
        &backup,
        BACKUP_ENDPOINT_FILL,
        active.now(),
    );
    let joined = join_group(&active, &backup_device, member).await;
    assert_eq!(joined.status, StatusCode::OK, "{joined:?}");
    GroupFixture {
        active,
        account,
        backup,
        backup_device,
    }
}

pub fn replica_path(after: u64) -> String {
    format!("{SERVER_GROUP_REPLICA}?after={after}")
}

pub async fn fetch_replica_bytes(
    source: &TestServer,
    member_device: &DeviceIdentity,
    after: u64,
) -> Vec<u8> {
    let response = source.get(member_device, &replica_path(after)).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.body
}

pub async fn copy_between(
    source: &TestServer,
    target: &TestServer,
    member_device: &DeviceIdentity,
) -> Result<(), ServerError> {
    let after = target.server.snapshot_state()?.revision;
    let replica_bytes =
        fetch_replica_bytes(source, member_device, after).await;
    target
        .server
        .install_replica(&replica_bytes, &source.server.device_id())
}

pub async fn copy_to_backup(
    fixture: &GroupFixture,
) -> Result<(), ServerError> {
    copy_between(&fixture.active, &fixture.backup, &fixture.backup_device)
        .await
}
