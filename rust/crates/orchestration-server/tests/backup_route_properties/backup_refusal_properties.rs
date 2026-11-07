use axum::http::StatusCode;
use orchestration_api::routes::SERVER_GROUP;
use orchestration_api::server_group::ServerGroupView;
use orchestration_core::server_group::ServerStanding;
use proptest::prelude::*;

use crate::server_group_fixtures::{
    GroupFixture, copy_to_backup, replica_path, start_group,
};
use crate::test_client::block_on;

const ROUTE_CASES: u32 = 8;
const BACKUP_REFUSAL: &str = "this app server is a backup";
const NEAR_MISS_PATHS: [&str; 6] = [
    "/server-group/",
    "/server-group/replica",
    "/server-group/members",
    "/server-groups",
    "/SERVER-GROUP",
    "/server-group%2F",
];

fn start_copied_group() -> Result<GroupFixture, TestCaseError> {
    let fixture = block_on(start_group());
    block_on(copy_to_backup(&fixture))
        .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
    Ok(fixture)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ROUTE_CASES))]

    #[test]
    fn test_refuse_on_backup_property_a_backup_never_serves_the_replica(
        after_revision in any::<u64>(),
    ) {
        let fixture = start_copied_group()?;

        let answer = block_on(
            fixture
                .backup
                .get(&fixture.backup_device, &replica_path(after_revision)),
        );

        prop_assert_eq!(answer.status, StatusCode::MISDIRECTED_REQUEST);
        prop_assert_eq!(answer.error_message(), BACKUP_REFUSAL);
        let standing = fixture.backup.server.standing();
        prop_assert_eq!(standing, ServerStanding::Backup);
    }

    #[test]
    fn test_refuse_on_backup_property_a_backup_answers_the_group_view(
        query_value in "[a-z0-9]{0,8}",
    ) {
        let fixture = start_copied_group()?;
        let path = if query_value.is_empty() {
            SERVER_GROUP.to_owned()
        } else {
            format!("{SERVER_GROUP}?seen={query_value}")
        };

        let answer =
            block_on(fixture.backup.get(&fixture.account.owner, &path));

        prop_assert_eq!(answer.status, StatusCode::OK);
        let view: ServerGroupView = answer.json();
        prop_assert_eq!(view.standing, ServerStanding::Backup);
    }

    #[test]
    fn test_refuse_on_backup_property_near_miss_paths_are_refused(
        path_index in 0..NEAR_MISS_PATHS.len(),
    ) {
        let fixture = start_copied_group()?;
        let path = NEAR_MISS_PATHS[path_index];
        let owner = &fixture.account.owner;

        let answer = block_on(fixture.backup.get(owner, path));

        prop_assert_eq!(answer.status, StatusCode::MISDIRECTED_REQUEST);
        prop_assert_eq!(answer.error_message(), BACKUP_REFUSAL);
    }

    #[test]
    fn test_refuse_on_backup_property_the_active_still_serves_the_replica(
        _round in 0_u8..2,
    ) {
        let fixture = start_copied_group()?;

        let answer = block_on(
            fixture.active.get(&fixture.backup_device, &replica_path(0)),
        );

        prop_assert_eq!(answer.status, StatusCode::OK);
        prop_assert!(!answer.body.is_empty());
    }
}
