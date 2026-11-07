use proptest::prelude::*;
use serde_json::Value;

use crate::hosting_problem_steps::{
    HostingFailure, damaged_record_strategy, forget_device_on,
    has_hosted_files, hosting_failure_strategy, prepare_hosted_data,
    read_status_on, start_after_failure,
};
use crate::runtime_steps::start_runtime;
use crate::support::test_device::fail;

const HOSTING_CASES: u32 = 3;
const HOSTING_PROBLEM_FIELD: &str = "hosting_problem";
const MOST_STATUS_READS: usize = 3;

fn read_hosting_problem(status: &Value) -> String {
    let problem = status[HOSTING_PROBLEM_FIELD].as_str();
    problem.unwrap_or_default().to_owned()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOSTING_CASES))]

    #[test]
    fn test_restart_off_the_calling_thread_property_a_taken_port_starts(
        status_reads in 1..=MOST_STATUS_READS,
    ) {
        let failed =
            start_after_failure(&HostingFailure::TakenPort).map_err(fail)?;

        for _ in 0..status_reads {
            let status = read_status_on(&failed.runtime).map_err(fail)?;
            let problem = read_hosting_problem(&status);

            let port_text = failed.hosted.port.to_string();
            prop_assert!(problem.contains(&port_text), "{}", problem);
            prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
            prop_assert!(status["account"].is_object());
        }
        prop_assert!(failed.occupier.is_some());
    }

    #[test]
    fn test_restart_off_the_calling_thread_property_a_damaged_record_starts(
        damaged_bytes in damaged_record_strategy(),
    ) {
        let failure = HostingFailure::DamagedRecord(damaged_bytes);
        let failed = start_after_failure(&failure).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        let problem = read_hosting_problem(&status);
        prop_assert!(!problem.is_empty(), "{}", status);
        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
        prop_assert!(has_hosted_files(&failed.hosted));
    }

    #[test]
    fn test_forget_hosted_app_server_property_forgetting_clears_the_problem(
        failure in hosting_failure_strategy(),
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;

        let forgotten = forget_device_on(&failed.runtime);
        let status = read_status_on(&failed.runtime).map_err(fail)?;
        drop(failed.runtime);
        let data_directory = failed.hosted.data_directory.path();
        let restarted = start_runtime(data_directory, failed.hosted.port)
            .map_err(fail)?;
        let restarted_status = read_status_on(&restarted).map_err(fail)?;

        prop_assert_eq!(forgotten, Ok(Value::Null));
        prop_assert_eq!(&status[HOSTING_PROBLEM_FIELD], &Value::Null);
        prop_assert_eq!(&status["account"], &Value::Null);
        prop_assert!(!has_hosted_files(&failed.hosted));
        let restarted_problem = &restarted_status[HOSTING_PROBLEM_FIELD];
        prop_assert_eq!(restarted_problem, &Value::Null);
    }

    #[test]
    fn test_describe_status_property_a_running_host_names_no_problem(
        restart_count in 1_usize..3,
    ) {
        let hosted = prepare_hosted_data().map_err(fail)?;
        let data_directory = hosted.data_directory.path();

        for _ in 0..restart_count {
            let runtime =
                start_runtime(data_directory, hosted.port).map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;

            prop_assert_eq!(&status[HOSTING_PROBLEM_FIELD], &Value::Null);
            prop_assert!(status["hosted_server_address"].is_string());
        }
    }
}
