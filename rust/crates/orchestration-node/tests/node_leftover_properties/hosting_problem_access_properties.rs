use std::fs;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::at_once::{run_at_once, run_both_at_once};
use crate::hosting_problem_steps::{
    HostingFailure, damaged_record_strategy, forget_device_on,
    hosting_failure_strategy, prepare_hosted_data, read_status_on,
    start_after_failure,
};
use crate::runtime_steps::{host_on, hosted_record_in, start_runtime};
use crate::support::hosting_steps::read_status;
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const ACCESS_CASES: u32 = 3;
const HOSTING_PROBLEM_FIELD: &str = "hosting_problem";
const PORT_REFUSAL_START: &str = "the app server cannot listen on port ";
const UNREADABLE_RECORD_START: &str = "could not encode or decode JSON: ";
const MOST_READS: usize = 3;

fn read_hosting_problem(status: &Value) -> Value {
    status[HOSTING_PROBLEM_FIELD].clone()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACCESS_CASES))]

    #[test]
    fn test_record_hosting_problem_property_a_taken_port_names_its_port(
        read_count in 1..=MOST_READS,
    ) {
        let failed =
            start_after_failure(&HostingFailure::TakenPort).map_err(fail)?;

        let expected_start =
            format!("{PORT_REFUSAL_START}{}: ", failed.hosted.port);
        for _ in 0..read_count {
            let status = read_status_on(&failed.runtime).map_err(fail)?;
            let problem = read_hosting_problem(&status);
            let problem_text = problem.as_str().unwrap_or_default();
            let names_the_port = problem_text.starts_with(&expected_start);
            prop_assert!(names_the_port, "{}", problem);
        }
    }

    #[test]
    fn test_record_hosting_problem_property_a_damaged_record_is_named(
        damaged_bytes in damaged_record_strategy(),
    ) {
        let failure = HostingFailure::DamagedRecord(damaged_bytes);
        let failed = start_after_failure(&failure).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        let problem = read_hosting_problem(&status);
        let problem_text = problem.as_str().unwrap_or_default();
        prop_assert!(
            problem_text.starts_with(UNREADABLE_RECORD_START),
            "{}",
            problem
        );
    }

    #[test]
    fn test_record_hosting_problem_property_the_problem_stays_put(
        failure in hosting_failure_strategy(),
        read_count in 2..=MOST_READS,
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;
        let first_status = read_status_on(&failed.runtime).map_err(fail)?;
        let first_problem = read_hosting_problem(&first_status);

        for _ in 1..read_count {
            let status = read_status_on(&failed.runtime).map_err(fail)?;
            let problem = read_hosting_problem(&status);
            prop_assert_eq!(problem, first_problem.clone());
        }
        prop_assert!(first_problem.is_string());
    }

    #[test]
    fn test_hosting_problem_property_a_fresh_device_names_none(
        read_count in 1..=MOST_READS,
    ) {
        let device = TestDevice::start().map_err(fail)?;

        for _ in 0..read_count {
            let status = read_status(&device).map_err(fail)?;
            prop_assert_eq!(read_hosting_problem(&status), Value::Null);
        }
    }

    #[test]
    fn test_hosting_problem_property_a_web_account_names_none(
        restart_count in 0_usize..2,
    ) {
        let server = TestServer::start().map_err(fail)?;
        let mut device = TestDevice::start().map_err(fail)?;
        device.create_account(&server, "acme").map_err(fail)?;
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
        }

        let status = read_status(&device).map_err(fail)?;

        prop_assert!(status["account"].is_object());
        prop_assert_eq!(read_hosting_problem(&status), Value::Null);
    }

    #[test]
    fn test_hosting_problem_property_only_a_failed_restart_names_one(
        failure in prop::option::of(hosting_failure_strategy()),
    ) {
        let status = if let Some(failure) = &failure {
            let failed = start_after_failure(failure).map_err(fail)?;
            read_status_on(&failed.runtime).map_err(fail)?
        } else {
            let hosted = prepare_hosted_data().map_err(fail)?;
            let data_directory = hosted.data_directory.path();
            let runtime =
                start_runtime(data_directory, hosted.port).map_err(fail)?;
            read_status_on(&runtime).map_err(fail)?
        };

        let problem = read_hosting_problem(&status);
        prop_assert_eq!(problem.is_string(), failure.is_some());
        let is_hosting = status["hosted_server_address"].is_string();
        prop_assert_eq!(is_hosting, failure.is_none());
    }

    #[test]
    fn test_forget_hosting_problem_property_forgetting_twice_stays_clear(
        failure in hosting_failure_strategy(),
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;

        let first_forget = forget_device_on(&failed.runtime);
        let second_forget = forget_device_on(&failed.runtime);
        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert_eq!(first_forget, Ok(Value::Null));
        prop_assert_eq!(second_forget, Ok(Value::Null));
        prop_assert_eq!(read_hosting_problem(&status), Value::Null);
    }

    #[test]
    fn test_forget_hosting_problem_property_hosting_again_names_none(
        damaged_bytes in damaged_record_strategy(),
    ) {
        let failure = HostingFailure::DamagedRecord(damaged_bytes);
        let failed = start_after_failure(&failure).map_err(fail)?;
        forget_device_on(&failed.runtime).map_err(fail)?;

        host_on(&failed.runtime).map_err(fail)?;
        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert_eq!(read_hosting_problem(&status), Value::Null);
        prop_assert!(status["hosted_server_address"].is_string());
    }

    #[test]
    fn test_forget_hosting_problem_property_forgetting_a_healthy_host(
        read_count in 1..=MOST_READS,
    ) {
        let hosted = prepare_hosted_data().map_err(fail)?;
        let data_directory = hosted.data_directory.path();
        let runtime =
            start_runtime(data_directory, hosted.port).map_err(fail)?;

        forget_device_on(&runtime).map_err(fail)?;

        for _ in 0..read_count {
            let status = read_status_on(&runtime).map_err(fail)?;
            prop_assert_eq!(read_hosting_problem(&status), Value::Null);
            prop_assert_eq!(&status["account"], &Value::Null);
        }
        prop_assert!(!hosted_record_in(data_directory).exists());
    }

    #[test]
    fn test_lock_hosting_problem_property_reads_at_once_agree(
        failure in hosting_failure_strategy(),
        reader_count in 2_usize..4,
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;

        let reading = || read_status_on(&failed.runtime);
        let statuses = run_at_once(reader_count, &reading);

        let mut problems = Vec::new();
        for status in statuses {
            let status = status.map_err(fail)?;
            problems.push(read_hosting_problem(&status));
        }
        prop_assert!(problems[0].is_string());
        for problem in &problems {
            prop_assert_eq!(problem, &problems[0]);
        }
    }

    #[test]
    fn test_lock_hosting_problem_property_reads_during_forget_stay_defined(
        failure in hosting_failure_strategy(),
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;
        let before = read_status_on(&failed.runtime).map_err(fail)?;
        let problem_before = read_hosting_problem(&before);

        let forgetting = || forget_device_on(&failed.runtime);
        let reading = || read_status_on(&failed.runtime);
        let (forgotten, read_during) = run_both_at_once(&forgetting, &reading);
        let after = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert_eq!(forgotten, Ok(Value::Null));
        if let Ok(status) = read_during {
            let problem_during = read_hosting_problem(&status);
            let is_defined = problem_during == problem_before
                || problem_during == Value::Null;
            prop_assert!(is_defined, "{}", problem_during);
        }
        prop_assert_eq!(read_hosting_problem(&after), Value::Null);
    }

    #[test]
    fn test_lock_hosting_problem_property_a_repaired_restart_starts_clear(
        damaged_bytes in damaged_record_strategy(),
    ) {
        let failure = HostingFailure::DamagedRecord(damaged_bytes);
        let failed = start_after_failure(&failure).map_err(fail)?;
        drop(failed.runtime);
        let data_directory = failed.hosted.data_directory.path();
        let repaired_record = json!({ "port": failed.hosted.port });
        let record_path = hosted_record_in(data_directory);
        fs::write(record_path, repaired_record.to_string()).map_err(fail)?;

        let restarted =
            start_runtime(data_directory, failed.hosted.port).map_err(fail)?;
        let status = read_status_on(&restarted).map_err(fail)?;

        prop_assert_eq!(read_hosting_problem(&status), Value::Null);
        prop_assert!(status["hosted_server_address"].is_string());
    }

    #[test]
    fn test_restart_off_the_calling_thread_property_keeps_a_damaged_record(
        damaged_bytes in damaged_record_strategy(),
    ) {
        let failure = HostingFailure::DamagedRecord(damaged_bytes.clone());
        let failed = start_after_failure(&failure).map_err(fail)?;
        let data_directory = failed.hosted.data_directory.path();

        read_status_on(&failed.runtime).map_err(fail)?;
        let kept_bytes =
            fs::read(hosted_record_in(data_directory)).map_err(fail)?;

        prop_assert_eq!(kept_bytes, damaged_bytes);
    }
}
