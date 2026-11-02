use std::thread;
use std::time::Duration;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::fake_engine::{
    EngineAnswers, EngineRunner, container_sandbox, local_sandbox,
};
use crate::support::test_device::{TestDevice, read_success};
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

const HEARTBEAT_LIMIT: Duration = Duration::from_secs(20);
const LONGER_THAN_A_CLAIM_INTERVAL: Duration = Duration::from_secs(7);
const PARSING_CASES: u32 = 24;
const NOT_A_RUNNER: &str = "this device cannot run tasks";
const STOPPED_PROBLEM: &str =
    "Docker is not running — start Docker and wait until it is ready";
const MISSING_IMAGE: EngineAnswers = EngineAnswers {
    info_exit_code: 0,
    image_exit_code: 1,
};
const STOPPED_ENGINE: EngineAnswers = EngineAnswers {
    info_exit_code: 1,
    image_exit_code: 1,
};

fn start_engine_runner(
    sandbox: &Value,
    answers: EngineAnswers,
) -> EngineRunner {
    let Ok(started) = EngineRunner::start(sandbox, answers) else {
        panic!("the runner node starts with an account");
    };
    started
}

fn wait_for_runner_requests(started: &EngineRunner) -> Result<(), String> {
    wait_for(HEARTBEAT_LIMIT, "the runner to talk to the server", || {
        Ok((started.count_runner_requests() > 0).then_some(()))
    })
}

fn read_sandbox_kind(status: &Value) -> Value {
    status["runner_settings"]["sandbox"]["kind"].clone()
}

#[test]
fn choosing_local_starts_a_blocked_container_runner_at_once() {
    let started = start_engine_runner(&container_sandbox(), MISSING_IMAGE);
    let blocked = started.read_status();

    let chosen = started.choose_place("local_process");
    let status = started.read_status();
    let runners = started.list_runners();

    assert!(blocked["runner_problem"].is_string(), "{blocked}");
    assert_eq!(chosen, Ok(Value::Null));
    assert_eq!(status["runner_problem"], Value::Null, "{status}");
    assert_eq!(read_sandbox_kind(&status), "local_process");
    assert_eq!(wait_for_runner_requests(&started), Ok(()));
    let Ok(runners) = runners else {
        panic!("the runners are listed");
    };
    assert_eq!(runners["this_device_problem"], Value::Null);
    assert_eq!(
        runners["this_device_settings"]["sandbox"]["kind"],
        "local_process"
    );
}

#[test]
fn choosing_docker_while_it_is_stopped_shows_the_problem_and_stops() {
    let started = start_engine_runner(&local_sandbox(), STOPPED_ENGINE);
    let Ok(()) = wait_for_runner_requests(&started) else {
        panic!("the local runner talks to the server");
    };

    let chosen = started.choose_place("container");
    let status = started.read_status();
    let requests_when_chosen = started.count_runner_requests();
    thread::sleep(LONGER_THAN_A_CLAIM_INTERVAL);

    assert_eq!(chosen, Ok(Value::Null));
    assert_eq!(status["runner_problem"], json!(STOPPED_PROBLEM), "{status}");
    assert_eq!(read_sandbox_kind(&status), "container");
    assert_eq!(started.count_runner_requests(), requests_when_chosen);
}

#[test]
fn the_choice_survives_a_restart() {
    let started = start_engine_runner(&container_sandbox(), MISSING_IMAGE);
    let Ok(Value::Null) = started.choose_place("local_process") else {
        panic!("local processes are chosen");
    };

    let Ok(restarted) = started.restart() else {
        panic!("the runner node starts again");
    };
    let status = restarted.read_status();

    assert_eq!(read_sandbox_kind(&status), "local_process", "{status}");
    assert_eq!(status["runner_problem"], Value::Null, "{status}");
}

#[test]
fn a_device_that_runs_no_agents_refuses_the_choice() {
    let Ok(server) = TestServer::start() else {
        panic!("the server starts");
    };
    let Ok(device) = TestDevice::start() else {
        panic!("the device starts");
    };
    let Ok(_) = device.create_account(&server, "acme") else {
        panic!("the account is created");
    };

    let reply = device.send(&json!({
        "command": "choose_agent_place",
        "place": "local_process",
    }));

    assert_eq!(read_success(&reply).err(), Some(NOT_A_RUNNER.to_owned()));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_choose_agent_place_property_unknown_places_are_refused(
        place in "[a-z_ ]{0,20}",
    ) {
        prop_assume!(place != "container" && place != "local_process");
        let device = TestDevice::start()
            .map_err(TestCaseError::fail)?;

        let reply = device.send(&json!({
            "command": "choose_agent_place",
            "place": place,
        }));

        let problem = read_success(&reply).err().unwrap_or_default();
        prop_assert!(
            problem.starts_with("invalid arguments for choose_agent_place"),
            "{}",
            problem
        );
    }
}
