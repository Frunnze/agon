use axum::http::StatusCode;
use chrono::TimeDelta;
use orchestration_api::accounts::{RevokeDeviceRequest, revocation_statement};
use orchestration_api::routes::{HEALTH, SERVER_GROUP};
use orchestration_api::server_group::ServerGroupView;
use orchestration_api::updates::AuditView;
use orchestration_core::device::DeviceRole;
use orchestration_core::server_group::ServerStanding;
use proptest::prelude::*;

use crate::fixtures::{create_account, identity_from_seed, pair_device};
use crate::server_group_fixtures::{
    BACKUP_ENDPOINT_FILL, FOUNDING_TERM_NUMBER, found_group_on, join_group,
    member_for, replica_path, start_group,
};
use crate::test_client::{TestServer, block_on};

const FIRST_CLIENT_SEED: u8 = 60;
const RUNNER_SEED: u8 = 80;
const STRANGER_SEED: u8 = 90;
const MOST_EXTRA_BACKUPS: u8 = 3;
const GROUP_CASES: u32 = 6;

fn read_group(test: &TestServer, account_owner_seed: u8) -> ServerGroupView {
    let reader = identity_from_seed(account_owner_seed);
    block_on(test.get(&reader, SERVER_GROUP)).json()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GROUP_CASES))]

    #[test]
    fn test_register_member_property_adds_backups_in_join_order(
        extra_backups in 1..=MOST_EXTRA_BACKUPS,
    ) {
        let fixture = block_on(start_group());
        let mut expected_order = vec![fixture.backup.server.device_id()];
        let mut extra_servers = Vec::new();
        for offset in 0..extra_backups {
            let device = identity_from_seed(FIRST_CLIENT_SEED + offset);
            let name = format!("client-{offset}");
            block_on(pair_device(
                &fixture.active,
                &fixture.account,
                &device,
                &name,
                DeviceRole::Client,
            ));
            fixture.active.clock.advance(TimeDelta::seconds(1));
            let server = TestServer::start();
            let fill = BACKUP_ENDPOINT_FILL + 1 + offset;
            let member =
                member_for(&device, &server, fill, fixture.active.now());
            let joined =
                block_on(join_group(&fixture.active, &device, member));
            prop_assert_eq!(joined.status, StatusCode::OK);
            expected_order.push(server.server.device_id());
            extra_servers.push(server);
        }

        let view = read_group(&fixture.active, crate::fixtures::OWNER_SEED);
        let backup_order: Vec<_> = view
            .group
            .backups_in_order()
            .into_iter()
            .map(|member| member.membership.server_id.clone())
            .collect();

        prop_assert_eq!(backup_order, expected_order);
        prop_assert_eq!(view.standing, ServerStanding::Active);
        prop_assert_eq!(
            view.group.active_server_id(),
            Some(&fixture.active.server.device_id())
        );
    }

    #[test]
    fn test_register_member_property_refuses_another_devices_membership(
        offset in 0u8..4,
    ) {
        let fixture = block_on(start_group());
        let other = identity_from_seed(FIRST_CLIENT_SEED + offset);
        block_on(pair_device(
            &fixture.active,
            &fixture.account,
            &other,
            "other-mac",
            DeviceRole::Client,
        ));
        let server = TestServer::start();
        let member = member_for(&other, &server, 30, fixture.active.now());

        let refused =
            block_on(join_group(
                &fixture.active,
                &fixture.backup_device,
                member,
            ));

        prop_assert_eq!(refused.status, StatusCode::FORBIDDEN);
        prop_assert_eq!(
            refused.error_message(),
            "a device can only add its own app server"
        );
    }
}

#[test]
fn test_found_group_property_makes_the_founder_active_in_term_one() {
    let test = TestServer::start();
    let account = block_on(create_account(&test));
    let founder = found_group_on(&test, &account);

    let view = read_group(&test, crate::fixtures::OWNER_SEED);
    let audit: AuditView = block_on(test.get(&account.owner, "/audit")).json();

    let term = view.group.term.clone().expect("the group has a term");
    assert_eq!(term.number, FOUNDING_TERM_NUMBER);
    assert_eq!(term.server_id, test.server.device_id());
    assert_eq!(view.group.members, vec![founder]);
    assert_eq!(view.standing, ServerStanding::Active);
    assert!(audit.intact);
}

#[test]
fn test_register_member_property_needs_a_founded_client_of_the_account() {
    let test = TestServer::start();
    let account = block_on(create_account(&test));
    let runner = identity_from_seed(RUNNER_SEED);
    block_on(pair_device(
        &test,
        &account,
        &runner,
        "gpu-box",
        DeviceRole::Runner,
    ));
    let stranger = identity_from_seed(STRANGER_SEED);
    let owner_member = member_for(&account.owner, &test, 3, test.now());
    let runner_member = member_for(&runner, &test, 4, test.now());
    let stranger_member = member_for(&stranger, &test, 5, test.now());

    let unfounded = block_on(join_group(&test, &account.owner, owner_member));
    found_group_on(&test, &account);
    let from_runner = block_on(join_group(&test, &runner, runner_member));
    let from_stranger =
        block_on(join_group(&test, &stranger, stranger_member));

    assert_eq!(unfounded.status, StatusCode::CONFLICT);
    assert_eq!(unfounded.error_message(), "the app server keeps no backups");
    assert_eq!(from_runner.status, StatusCode::FORBIDDEN);
    assert_eq!(from_stranger.status, StatusCode::UNAUTHORIZED);
}

#[test]
fn test_remove_member_property_only_a_backup_leaves_and_only_by_itself() {
    let fixture = block_on(start_group());
    let owner = &fixture.account.owner;
    let backup_id = fixture.backup_device.device_id().0;
    let owner_id = owner.device_id().0;

    let active_leaves = block_on(
        fixture
            .active
            .delete(owner, &format!("{SERVER_GROUP}/members/{owner_id}")),
    );
    let removed_by_other = block_on(
        fixture
            .active
            .delete(owner, &format!("{SERVER_GROUP}/members/{backup_id}")),
    );
    let removed_by_itself = block_on(fixture.active.delete(
        &fixture.backup_device,
        &format!("{SERVER_GROUP}/members/{backup_id}"),
    ));
    let view = read_group(&fixture.active, crate::fixtures::OWNER_SEED);

    assert_eq!(active_leaves.status, StatusCode::CONFLICT);
    assert_eq!(removed_by_other.status, StatusCode::FORBIDDEN);
    assert_eq!(removed_by_itself.status, StatusCode::OK);
    assert_eq!(view.group.members.len(), 1);
}

#[test]
fn test_revoke_device_property_removes_its_backup() {
    let fixture = block_on(start_group());
    let owner = &fixture.account.owner;
    let backup_id = fixture.backup_device.device_id();
    let request = RevokeDeviceRequest {
        approval_signature: owner.sign(&revocation_statement(&backup_id)),
    };

    let revoked = block_on(fixture.active.post(
        owner,
        &format!("/devices/{}/revoke", backup_id.0),
        &request,
    ));
    let view = read_group(&fixture.active, crate::fixtures::OWNER_SEED);

    assert_eq!(revoked.status, StatusCode::OK, "{revoked:?}");
    assert_eq!(view.group.members.len(), 1);
    assert!(view.group.find_member_of_device(&backup_id).is_none());
}

#[test]
fn test_fetch_replica_property_only_devices_keeping_the_server_copy_it() {
    let fixture = block_on(start_group());
    let other = identity_from_seed(FIRST_CLIENT_SEED);
    block_on(pair_device(
        &fixture.active,
        &fixture.account,
        &other,
        "other-mac",
        DeviceRole::Client,
    ));

    let from_member =
        block_on(fixture.active.get(&fixture.backup_device, &replica_path(0)));
    let from_other = block_on(fixture.active.get(&other, &replica_path(0)));

    assert_eq!(from_member.status, StatusCode::OK);
    assert_eq!(from_other.status, StatusCode::FORBIDDEN);
}

#[test]
fn test_refuse_on_backup_property_a_backup_answers_only_the_group_view() {
    let fixture = block_on(start_group());
    let owner = &fixture.account.owner;

    let health = block_on(fixture.backup.send_unsigned(
        axum::http::Method::GET,
        HEALTH,
        Vec::new(),
    ));
    let projects = block_on(fixture.backup.get(owner, "/projects"));

    assert_eq!(health.status, StatusCode::MISDIRECTED_REQUEST);
    assert_eq!(health.error_message(), "this app server is a backup");
    assert_eq!(projects.status, StatusCode::MISDIRECTED_REQUEST);
    assert_eq!(fixture.backup.server.standing(), ServerStanding::Backup);
}
