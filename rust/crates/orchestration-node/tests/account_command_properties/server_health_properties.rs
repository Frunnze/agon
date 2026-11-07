use chrono::{DateTime, Utc};
use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    NODE_CASES, PARSING_CASES, collect_names, read_field_names, retry_server,
    shared_fresh_device, start_device_with_account,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const MOST_CHECKS: usize = 4;
const NO_APP_SERVER: &str = "this device has no app server yet";
const UNREACHABLE_PREFIX: &str = "could not reach the app server";
const HEALTH_FIELDS: [&str; 3] = ["reachable", "checked_at", "problem"];
const UTC_SUFFIX: &str = "Z";

#[derive(Clone, Copy, Debug)]
enum ServerStage {
    NoServer,
    Running,
    Stopped,
}

fn server_stage_strategy() -> impl Strategy<Value = ServerStage> {
    prop_oneof![
        Just(ServerStage::NoServer),
        Just(ServerStage::Running),
        Just(ServerStage::Stopped),
    ]
}

fn reach_server_stage(
    stage: ServerStage,
) -> Result<(TestDevice, Option<TestServer>), TestCaseError> {
    if let ServerStage::NoServer = stage {
        let device = TestDevice::start().map_err(fail)?;
        return Ok((device, None));
    }
    let (device, server, _) = start_device_with_account()?;
    if let ServerStage::Stopped = stage {
        server.stop().map_err(fail)?;
    }
    Ok((device, Some(server)))
}

fn read_checked_at(health: &Value) -> Result<DateTime<Utc>, TestCaseError> {
    let checked_text = health["checked_at"].as_str().unwrap_or_default();
    let checked_at = DateTime::parse_from_rfc3339(checked_text)
        .map_err(|problem| fail(format!("{checked_text}: {problem}")))?;
    Ok(checked_at.with_timezone(&Utc))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_check_server_property_no_server_is_never_reachable(
        checks in 1..MOST_CHECKS,
    ) {
        let device = shared_fresh_device()?;

        for _ in 0..checks {
            let health = retry_server(device)?;
            prop_assert_eq!(&health["reachable"], &Value::Bool(false));
            prop_assert_eq!(&health["problem"], NO_APP_SERVER);
        }
    }

    #[test]
    fn test_check_server_property_checked_at_is_the_moment_of_the_check(
        checks in 1..MOST_CHECKS,
    ) {
        let device = shared_fresh_device()?;
        let mut previous_check = DateTime::<Utc>::MIN_UTC;

        for _ in 0..checks {
            let before = Utc::now();
            let health = retry_server(device)?;
            let after = Utc::now();
            let checked_at = read_checked_at(&health)?;
            prop_assert!(before <= checked_at && checked_at <= after);
            prop_assert!(previous_check <= checked_at);
            previous_check = checked_at;
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_check_server_property_follows_the_stored_server(
        stops_server in any::<bool>(),
        checks in 1..MOST_CHECKS,
    ) {
        let (device, server, _) = start_device_with_account()?;
        if stops_server {
            server.stop().map_err(fail)?;
        }

        for _ in 0..checks {
            let health = retry_server(&device)?;
            prop_assert_eq!(&health["reachable"], &Value::Bool(!stops_server));
            let problem = health["problem"].as_str().unwrap_or_default();
            let names_the_outage = problem.starts_with(UNREACHABLE_PREFIX);
            prop_assert_eq!(names_the_outage, stops_server);
        }
    }

    #[test]
    fn test_server_health_view_property_has_exactly_the_contract_fields(
        stage in server_stage_strategy(),
    ) {
        let (device, _server) = reach_server_stage(stage)?;

        let health = retry_server(&device)?;

        let expected_fields = collect_names(&HEALTH_FIELDS);
        prop_assert_eq!(read_field_names(&health), expected_fields);
    }

    #[test]
    fn test_server_health_view_property_checked_at_is_an_utc_moment(
        stage in server_stage_strategy(),
    ) {
        let (device, _server) = reach_server_stage(stage)?;

        let health = retry_server(&device)?;

        let checked_text = health["checked_at"].as_str().unwrap_or_default();
        prop_assert!(checked_text.ends_with(UTC_SUFFIX), "{checked_text}");
        let checked_at = read_checked_at(&health)?;
        prop_assert!(checked_at <= Utc::now());
    }

    #[test]
    fn test_server_health_view_property_a_problem_exactly_when_unreachable(
        stage in server_stage_strategy(),
    ) {
        let (device, _server) = reach_server_stage(stage)?;

        let health = retry_server(&device)?;

        let reachable = health["reachable"].as_bool();
        let expected_reachable = matches!(stage, ServerStage::Running);
        prop_assert_eq!(reachable, Some(expected_reachable));
        let problem = health["problem"].as_str();
        prop_assert_eq!(problem.is_none(), reachable == Some(true));
        prop_assert!(problem.is_none_or(|text| !text.trim().is_empty()));
    }
}
