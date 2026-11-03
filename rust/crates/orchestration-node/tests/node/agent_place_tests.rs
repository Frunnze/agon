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
const NO_OFFERS: &str = "a runner offers at least one place for agents to run";
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
const READY_ENGINE: EngineAnswers = EngineAnswers {
    info_exit_code: 0,
    image_exit_code: 0,
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

fn wait_for_offers(
    started: &EngineRunner,
    expected: &Value,
) -> Result<(), String> {
    wait_for(HEARTBEAT_LIMIT, "a heartbeat with the offers", || {
        let offers = started.read_last_heartbeat_offers();
        Ok((offers.as_ref() == Some(expected)).then_some(()))
    })
}

fn list_offers(started: &EngineRunner) -> Value {
    let Ok(runners) = started.list_runners() else {
        panic!("the runners are listed");
    };
    runners["this_device_offers"].clone()
}

#[test]
fn offering_this_computer_too_starts_a_blocked_container_runner() {
    let started = start_engine_runner(&container_sandbox(), MISSING_IMAGE);
    let blocked = started.read_status();

    let chosen = started.choose_offers(&json!(["container", "local_process"]));
    let status = started.read_status();
    let offers = list_offers(&started);

    assert!(blocked["runner_problem"].is_string(), "{blocked}");
    assert_eq!(chosen, Ok(Value::Null));
    assert_eq!(status["runner_problem"], Value::Null, "{status}");
    assert_eq!(
        offers[0],
        json!({"place": "local_process", "problem": null})
    );
    assert_eq!(offers[1]["place"], "container", "{offers}");
    assert!(offers[1]["problem"].is_string(), "{offers}");
    assert_eq!(wait_for_offers(&started, &json!(["local_process"])), Ok(()));
}

#[test]
fn a_ready_docker_is_offered_beside_this_computer() {
    let started = start_engine_runner(&local_sandbox(), READY_ENGINE);

    let chosen = started.choose_offers(&json!(["local_process", "container"]));
    let offers = list_offers(&started);

    assert_eq!(chosen, Ok(Value::Null));
    assert_eq!(
        offers,
        json!([
            {"place": "local_process", "problem": null},
            {"place": "container", "problem": null},
        ])
    );
    assert_eq!(
        wait_for_offers(&started, &json!(["local_process", "container"])),
        Ok(())
    );
}

#[test]
fn offering_only_a_stopped_docker_shows_the_problem_and_stops() {
    let started = start_engine_runner(&local_sandbox(), STOPPED_ENGINE);
    let Ok(()) = wait_for_runner_requests(&started) else {
        panic!("the local runner talks to the server");
    };

    let chosen = started.choose_offers(&json!(["container"]));
    let status = started.read_status();
    let offers = list_offers(&started);
    let requests_when_chosen = started.count_runner_requests();
    thread::sleep(LONGER_THAN_A_CLAIM_INTERVAL);

    assert_eq!(chosen, Ok(Value::Null));
    assert_eq!(status["runner_problem"], json!(STOPPED_PROBLEM), "{status}");
    assert_eq!(
        offers,
        json!([{"place": "container", "problem": STOPPED_PROBLEM}])
    );
    assert_eq!(started.count_runner_requests(), requests_when_chosen);
}

#[test]
fn the_offers_survive_a_restart() {
    let started = start_engine_runner(&container_sandbox(), MISSING_IMAGE);
    let Ok(Value::Null) = started.choose_offers(&json!(["local_process"]))
    else {
        panic!("this computer is offered");
    };

    let Ok(restarted) = started.restart() else {
        panic!("the runner node starts again");
    };
    let status = restarted.read_status();
    let offers = list_offers(&restarted);

    assert_eq!(status["runner_problem"], Value::Null, "{status}");
    assert_eq!(offers, json!([{"place": "local_process", "problem": null}]));
}

#[test]
fn an_older_single_choice_becomes_that_one_offer() {
    let started = start_engine_runner(&container_sandbox(), MISSING_IMAGE);
    let Ok(()) = started.write_older_place_choice("local_process") else {
        panic!("the older choice is written");
    };

    let Ok(restarted) = started.restart() else {
        panic!("the runner node starts again");
    };
    let offers = list_offers(&restarted);

    assert_eq!(offers, json!([{"place": "local_process", "problem": null}]));
}

#[test]
fn offering_nothing_is_refused() {
    let started = start_engine_runner(&local_sandbox(), READY_ENGINE);

    let chosen = started.choose_offers(&json!([]));

    assert_eq!(chosen, Err(NO_OFFERS.to_owned()));
}

#[test]
fn a_device_that_runs_no_agents_refuses_the_offers() {
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
        "command": "choose_agent_offers",
        "offers": ["local_process"],
    }));

    assert_eq!(read_success(&reply).err(), Some(NOT_A_RUNNER.to_owned()));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_choose_agent_offers_property_unknown_places_are_refused(
        place in "[a-z_ ]{0,20}",
    ) {
        prop_assume!(place != "container" && place != "local_process");
        let device = TestDevice::start()
            .map_err(TestCaseError::fail)?;

        let reply = device.send(&json!({
            "command": "choose_agent_offers",
            "offers": [place],
        }));

        let problem = read_success(&reply).err().unwrap_or_default();
        prop_assert!(
            problem.starts_with("invalid arguments for choose_agent_offers"),
            "{}",
            problem
        );
    }
}
