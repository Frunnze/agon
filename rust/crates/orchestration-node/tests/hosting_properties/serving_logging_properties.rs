use std::net::{Ipv4Addr, SocketAddr};

use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::backup_group::{STEADY_TAKEOVER_SECONDS, start_backup_group};
use crate::hosting_desk::{heavy_cases, send_hostile_bytes};
use crate::logged_host::count_lines_starting;
use crate::process_group::{
    ProcessHosting, host_in_a_process, move_backup_into_a_process,
};
use crate::support::hosting_steps::{
    HEALTHY_ANSWER_START, read_health_answer,
};
use crate::support::test_device::fail;

const WEB_SERVING_LINE_START: &str = "the hosted app server stopped serving: ";
const WRITE_STOPPING_LINE_START: &str =
    "the stopped app server could not refuse writes: ";
const FORGET_COMMAND: &str = "forget_this_device";

fn hostile_requests_strategy() -> impl Strategy<Value = Vec<Vec<u8>>> {
    vec(vec(any::<u8>(), 0..256), 1..5)
}

fn forget(hosting: &mut ProcessHosting) -> Result<(), TestCaseError> {
    let forgotten = hosting.host.run(&json!({ "command": FORGET_COMMAND }));
    forgotten.map(|_| ()).map_err(fail)
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_log_web_serving_problem_property_hostile_bytes_are_not_logged(
        hostile_requests in hostile_requests_strategy(),
    ) {
        let hosting = host_in_a_process().map_err(fail)?;

        for hostile_bytes in &hostile_requests {
            send_hostile_bytes(hosting.port, hostile_bytes).map_err(fail)?;
        }
        let loopback = SocketAddr::from((Ipv4Addr::LOCALHOST, hosting.port));
        let health = read_health_answer(loopback).map_err(fail)?;
        let lines = hosting.host.stop().map_err(fail)?;

        prop_assert!(health.starts_with(HEALTHY_ANSWER_START), "{health}");
        let serving_lines =
            count_lines_starting(&lines, WEB_SERVING_LINE_START);
        prop_assert_eq!(serving_lines, 0);
    }

    #[test]
    fn test_log_web_serving_problem_property_a_stop_is_not_logged(
        _round in 0_u8..2,
    ) {
        let hosting = host_in_a_process().map_err(fail)?;

        let lines = hosting.host.stop().map_err(fail)?;

        let serving_lines =
            count_lines_starting(&lines, WEB_SERVING_LINE_START);
        prop_assert_eq!(serving_lines, 0);
    }

    #[test]
    fn test_log_web_serving_problem_property_forgetting_is_not_logged(
        _round in 0_u8..2,
    ) {
        let mut hosting = host_in_a_process().map_err(fail)?;

        forget(&mut hosting)?;
        let lines = hosting.host.stop().map_err(fail)?;

        let serving_lines =
            count_lines_starting(&lines, WEB_SERVING_LINE_START);
        prop_assert_eq!(serving_lines, 0);
    }

    #[test]
    fn test_log_write_stopping_problem_property_a_clean_stop_logs_nothing(
        _round in 0_u8..2,
    ) {
        let hosting = host_in_a_process().map_err(fail)?;

        let lines = hosting.host.stop().map_err(fail)?;

        prop_assert_eq!(
            count_lines_starting(&lines, WRITE_STOPPING_LINE_START),
            0
        );
    }

    #[test]
    fn test_log_write_stopping_problem_property_forgetting_logs_nothing(
        _round in 0_u8..2,
    ) {
        let mut hosting = host_in_a_process().map_err(fail)?;

        forget(&mut hosting)?;
        let lines = hosting.host.stop().map_err(fail)?;

        prop_assert_eq!(
            count_lines_starting(&lines, WRITE_STOPPING_LINE_START),
            0
        );
    }

    #[test]
    fn test_log_write_stopping_problem_property_a_left_backup_logs_nothing(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let mut backup =
            move_backup_into_a_process(group, STEADY_TAKEOVER_SECONDS)
                .map_err(fail)?;

        let stopped =
            backup.host.run(&json!({ "command": "stop_server_backup" }));
        let lines = backup.host.stop().map_err(fail)?;

        prop_assert!(stopped.is_ok(), "{stopped:?}");
        prop_assert_eq!(
            count_lines_starting(&lines, WRITE_STOPPING_LINE_START),
            0
        );
    }
}
