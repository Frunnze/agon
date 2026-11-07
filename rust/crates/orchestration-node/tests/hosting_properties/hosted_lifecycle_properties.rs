use std::fs;
use std::net::{Ipv4Addr, SocketAddr, TcpListener};
use std::path::PathBuf;
use std::thread;

use orchestration_node::node_runtime::NodeRuntime;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::hosting_desk::{
    heavy_cases, host_a_server, hosting_configuration,
    read_hosted_peer_address, read_loopback_health, send_hostile_bytes,
    shared_hosting, start_node_with, stop_and_keep_data,
};
use crate::local_announcements::{
    describe_announced_address, watch_for_announcement,
};
use crate::start_problem_reading::read_hosting_problem_after_start;
use crate::support::hosting_steps::{
    HEALTHY_ANSWER_START, HostingDevice, create_hosted_account,
    hosted_server_files, read_health_answer,
};
use crate::support::test_device::{TestDevice, fail};

const SERVER_FAILED_START: &str = "the app server on this device failed: ";
const SERVER_KEY_FILE_NAME: &str = "server-identity.key";
const FORGET_COMMAND: &str = "forget_this_device";

#[derive(Clone, Copy, Debug)]
enum HostingStep {
    Restart,
    ForgetAndHostAgain,
}

fn hosting_steps_strategy() -> impl Strategy<Value = Vec<HostingStep>> {
    let step = prop_oneof![
        Just(HostingStep::Restart),
        Just(HostingStep::ForgetAndHostAgain),
    ];
    vec(step, 1..4)
}

fn forget(device: &TestDevice) -> Result<(), TestCaseError> {
    let forgotten = device.run(&json!({ "command": FORGET_COMMAND }));
    if forgotten != Ok(Value::Null) {
        return Err(fail(format!("forgetting failed: {forgotten:?}")));
    }
    Ok(())
}

#[derive(Debug)]
struct DamagedServer {
    data_directory: TempDir,
    port: u16,
    original_key: Vec<u8>,
    key_path: PathBuf,
}

impl DamagedServer {
    fn start_node(&self) -> Result<NodeRuntime, String> {
        let configuration =
            hosting_configuration(self.data_directory.path(), self.port);
        start_node_with(&configuration)
    }

    fn read_start_problem(&self) -> Result<String, String> {
        let configuration =
            hosting_configuration(self.data_directory.path(), self.port);
        read_hosting_problem_after_start(&configuration)
    }
}

fn damage_the_server_key(
    damaged_key: &[u8],
) -> Result<DamagedServer, TestCaseError> {
    let HostingDevice { device, port, .. } = host_a_server().map_err(fail)?;
    let [server_directory, _record] = hosted_server_files(&device);
    let key_path = server_directory.join(SERVER_KEY_FILE_NAME);
    let data_directory = stop_and_keep_data(device);
    let original_key = fs::read(&key_path).map_err(fail)?;
    fs::write(&key_path, damaged_key).map_err(fail)?;
    Ok(DamagedServer {
        data_directory,
        port,
        original_key,
        key_path,
    })
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_hosted_app_server_stop_property_step_sequences_keep_identities(
        steps in hosting_steps_strategy(),
    ) {
        let HostingDevice { mut device, port, .. } =
            host_a_server().map_err(fail)?;
        let mut known = read_hosted_peer_address(&device).map_err(fail)?;

        for step in steps {
            match step {
                HostingStep::Restart => {
                    device = device.stop_and_start_again().map_err(fail)?;
                }
                HostingStep::ForgetAndHostAgain => {
                    forget(&device)?;
                    create_hosted_account(&device).map_err(fail)?;
                }
            }
            let current = read_hosted_peer_address(&device).map_err(fail)?;
            let current_key = current.endpoint_public_key;
            let is_same = current_key == known.endpoint_public_key;
            prop_assert_eq!(is_same, matches!(step, HostingStep::Restart));
            let health = read_loopback_health(port).map_err(fail)?;
            prop_assert!(health.starts_with(HEALTHY_ANSWER_START), "{health}");
            known = current;
        }
    }

    #[test]
    fn test_hosted_app_server_drop_property_forgetting_says_goodbye(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let wanted = describe_announced_address(&peer_address);
        let (watch, announced) =
            watch_for_announcement(&wanted).map_err(fail)?;

        forget(&hosting.device)?;
        let withdrawn = watch.wait_for_withdrawal(&announced.full_name);

        prop_assert!(withdrawn.is_ok(), "{withdrawn:?}");
    }

    #[test]
    fn test_hosted_app_server_drop_property_stopping_says_goodbye(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let wanted = describe_announced_address(&peer_address);
        let (watch, announced) =
            watch_for_announcement(&wanted).map_err(fail)?;

        let stopped = hosting.device.stop();
        let withdrawn = watch.wait_for_withdrawal(&announced.full_name);
        drop(stopped);

        prop_assert!(withdrawn.is_ok(), "{withdrawn:?}");
    }

    #[test]
    fn test_hosted_app_server_drop_property_forgetting_frees_the_port(
        _round in 0_u8..2,
    ) {
        let hosting = host_a_server().map_err(fail)?;

        forget(&hosting.device)?;
        let rebound = TcpListener::bind((Ipv4Addr::LOCALHOST, hosting.port));

        prop_assert!(rebound.is_ok(), "{rebound:?}");
    }

    #[test]
    fn test_serve_on_loopback_property_answers_sequential_requests(
        request_count in 1_usize..20,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        for _ in 0..request_count {
            let health = read_loopback_health(hosting.port).map_err(fail)?;
            prop_assert!(health.starts_with(HEALTHY_ANSWER_START), "{health}");
        }
    }

    #[test]
    fn test_serve_on_loopback_property_hostile_bytes_leave_it_serving(
        hostile_requests in vec(vec(any::<u8>(), 0..512), 1..6),
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        for hostile_bytes in &hostile_requests {
            send_hostile_bytes(hosting.port, hostile_bytes).map_err(fail)?;
        }
        let health = read_loopback_health(hosting.port).map_err(fail)?;

        prop_assert!(health.starts_with(HEALTHY_ANSWER_START), "{health}");
    }

    #[test]
    fn test_serve_on_loopback_property_answers_concurrent_requests(
        request_count in 2_usize..9,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let port = hosting.port;

        let answers: Vec<Result<String, String>> = thread::scope(|scope| {
            let mut askers = Vec::new();
            for _ in 0..request_count {
                let socket = SocketAddr::from((Ipv4Addr::LOCALHOST, port));
                askers.push(scope.spawn(move || read_health_answer(socket)));
            }
            let mut answers = Vec::new();
            for asker in askers {
                let answer = asker.join().unwrap_or_else(|_| {
                    Err("a health request panicked".to_owned())
                });
                answers.push(answer);
            }
            answers
        });

        for answer in answers {
            let answer = answer.map_err(fail)?;
            prop_assert!(answer.starts_with(HEALTHY_ANSWER_START), "{answer}");
        }
    }

    #[test]
    fn test_describe_hosted_server_problem_property_names_a_damaged_key(
        damaged_key in vec(any::<u8>(), 0..20),
    ) {
        let damaged = damage_the_server_key(&damaged_key)?;

        let started = damaged.read_start_problem();
        let key_after = fs::read(&damaged.key_path).map_err(fail)?;

        let Ok(problem) = started else {
            return Err(fail("a damaged server key was accepted"));
        };
        prop_assert!(problem.starts_with(SERVER_FAILED_START), "{problem}");
        prop_assert_eq!(key_after, damaged_key);
    }

    #[test]
    fn test_describe_hosted_server_problem_property_repeats_the_same_text(
        damaged_key in vec(any::<u8>(), 0..20),
    ) {
        let damaged = damage_the_server_key(&damaged_key)?;

        let first = damaged.read_start_problem().ok();
        let second = damaged.read_start_problem().ok();

        prop_assert!(first.is_some());
        prop_assert_eq!(first, second);
    }

    #[test]
    fn test_describe_hosted_server_problem_property_a_repaired_key_hosts(
        damaged_key in vec(any::<u8>(), 0..20),
    ) {
        let damaged = damage_the_server_key(&damaged_key)?;

        let refused = damaged.read_start_problem();
        fs::write(&damaged.key_path, &damaged.original_key).map_err(fail)?;
        let repaired = damaged.start_node();

        prop_assert!(refused.is_ok(), "{:?}", refused);
        prop_assert!(repaired.is_ok(), "{:?}", repaired.err());
        let health = read_loopback_health(damaged.port).map_err(fail)?;
        prop_assert!(health.starts_with(HEALTHY_ANSWER_START), "{health}");
    }
}
