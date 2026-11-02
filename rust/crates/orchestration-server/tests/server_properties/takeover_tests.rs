use std::time::{Duration, Instant};

use axum::http::StatusCode;
use orchestration_api::server_group::ServerGroupView;
use orchestration_api::updates::{AuditView, EventsResponse};
use orchestration_core::server_group::ServerStanding;
use orchestration_server::ServerError;

use crate::fixtures::{
    OWNER_SEED, create_account, create_project, identity_from_seed,
};
use crate::server_group_fixtures::{
    copy_between, copy_to_backup, fetch_replica_bytes, start_group, term_for,
};
use crate::test_client::{TestServer, block_on};

const TAKEOVER_TERM_NUMBER: u64 = 2;
const LOWER_TERM_NUMBER: u64 = 0;
const LONG_WAIT: Duration = Duration::from_secs(20);
const QUICK_ANSWER_LIMIT: Duration = Duration::from_secs(5);
const CURSOR_LEAD: u64 = 5;

fn take_over_on_backup(
    fixture: &crate::server_group_fixtures::GroupFixture,
) -> Result<(), ServerError> {
    let term = term_for(
        &fixture.backup_device,
        &fixture.backup,
        TAKEOVER_TERM_NUMBER,
    );
    fixture.backup.server.take_over(&term)
}

#[test]
fn test_take_over_property_the_backup_writes_only_after_taking_over() {
    let fixture = block_on(start_group());
    block_on(copy_to_backup(&fixture)).expect("the backup has a copy");
    let owner = &fixture.account.owner;

    let before = block_on(fixture.backup.get(owner, "/projects"));
    let took_over = take_over_on_backup(&fixture);
    block_on(create_project(&fixture.backup, &fixture.account));
    let view: ServerGroupView =
        block_on(fixture.backup.get(owner, "/server-group")).json();
    let audit: AuditView =
        block_on(fixture.backup.get(owner, "/audit")).json();

    assert_eq!(before.status, StatusCode::MISDIRECTED_REQUEST);
    assert_eq!(took_over, Ok(()));
    assert_eq!(view.standing, ServerStanding::Active);
    let term = view.group.term.expect("the group has a term");
    assert_eq!(term.number, TAKEOVER_TERM_NUMBER);
    assert_eq!(term.server_id, fixture.backup.server.device_id());
    assert!(audit.intact);
}

#[test]
fn test_take_over_property_refuses_a_term_that_is_not_higher_or_not_its_own() {
    let fixture = block_on(start_group());
    block_on(copy_to_backup(&fixture)).expect("the backup has a copy");
    let lower_term =
        term_for(&fixture.backup_device, &fixture.backup, LOWER_TERM_NUMBER);
    let claimed_by_owner = term_for(
        &fixture.account.owner,
        &fixture.backup,
        TAKEOVER_TERM_NUMBER,
    );

    let not_higher = fixture.backup.server.take_over(&lower_term);
    let not_hosting = fixture.backup.server.take_over(&claimed_by_owner);

    assert!(matches!(not_higher, Err(ServerError::Conflict(_))));
    assert!(matches!(not_hosting, Err(ServerError::Forbidden(_))));
    assert_eq!(fixture.backup.server.standing(), ServerStanding::Backup);
}

#[test]
fn test_step_down_property_the_old_active_refuses_writes_and_catches_up() {
    let fixture = block_on(start_group());
    block_on(copy_to_backup(&fixture)).expect("the backup has a copy");
    take_over_on_backup(&fixture).expect("the backup takes over");
    block_on(create_project(&fixture.backup, &fixture.account));
    let owner = &fixture.account.owner;

    fixture
        .active
        .server
        .step_down()
        .expect("the old active steps down");
    let refused = block_on(fixture.active.get(owner, "/projects"));
    let caught_up =
        block_on(copy_between(&fixture.backup, &fixture.active, owner));

    assert_eq!(refused.status, StatusCode::MISDIRECTED_REQUEST);
    assert_eq!(caught_up, Ok(()));
    assert_eq!(
        fixture.active.server.snapshot_state(),
        fixture.backup.server.snapshot_state()
    );
}

#[test]
fn test_install_replica_property_refuses_an_older_term() {
    let fixture = block_on(start_group());
    block_on(copy_to_backup(&fixture)).expect("the backup has a copy");
    take_over_on_backup(&fixture).expect("the backup takes over");
    fixture
        .backup
        .server
        .step_down()
        .expect("the backup steps down");
    block_on(create_project(&fixture.active, &fixture.account));
    let older_bytes = block_on(fetch_replica_bytes(
        &fixture.active,
        &fixture.backup_device,
        0,
    ));

    let older = fixture
        .backup
        .server
        .install_replica(&older_bytes, &fixture.active.server.device_id());

    assert!(matches!(older, Err(ServerError::Conflict(_))), "{older:?}");
}

#[test]
fn test_open_property_a_restarted_active_with_backups_waits_as_a_backup() {
    let fixture = block_on(start_group());

    let reopened = fixture.active.restart();
    let standing_at_start = reopened.server.standing();
    let resumed = reopened.server.resume_as_active();
    let backup_resumes = fixture.backup.server.resume_as_active();

    assert_eq!(standing_at_start, ServerStanding::Backup);
    assert_eq!(resumed, Ok(()));
    assert_eq!(reopened.server.standing(), ServerStanding::Active);
    assert!(matches!(backup_resumes, Err(ServerError::Conflict(_))));
}

#[test]
fn test_poll_events_property_a_cursor_ahead_of_the_server_answers_at_once() {
    let test = TestServer::start_with_long_poll_timeout(LONG_WAIT);
    block_on(create_account(&test));
    let owner = identity_from_seed(OWNER_SEED);
    let latest = test
        .server
        .snapshot_state()
        .expect("the state reads")
        .latest_sequence;

    let started = Instant::now();
    let path = format!("/events?after={}", latest + CURSOR_LEAD);
    let events: EventsResponse = block_on(test.get(&owner, &path)).json();

    assert!(started.elapsed() < QUICK_ANSWER_LIMIT);
    assert_eq!(events.notifications.len(), 0);
    assert_eq!(events.latest_sequence, latest);
}
