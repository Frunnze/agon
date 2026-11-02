use std::time::Duration;

use serde_json::{Value, json};

use crate::support::fake_engine::{
    DEFAULT_IMAGE, EngineAnswers, EngineRunner, container_sandbox,
};
use crate::support::waiting::wait_for;

const QUIET_PERIOD: Duration = Duration::from_secs(2);
const HEARTBEAT_LIMIT: Duration = Duration::from_secs(20);
const RUNNING_ENGINE_MISSING_IMAGE: EngineAnswers = EngineAnswers {
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

fn start_container_runner(answers: EngineAnswers) -> EngineRunner {
    let Ok(started) = EngineRunner::start(&container_sandbox(), answers)
    else {
        panic!("the container runner starts");
    };
    started
}

#[test]
fn a_missing_image_keeps_the_runner_from_claiming_and_says_why() {
    let started = start_container_runner(RUNNING_ENGINE_MISSING_IMAGE);

    std::thread::sleep(QUIET_PERIOD);
    let status = started.read_status();
    let runners = started.list_runners();

    let expected = format!(
        "The runner image {DEFAULT_IMAGE} is missing — \
         run scripts/build-runner-image.sh"
    );
    assert_eq!(status["runner_problem"], json!(expected), "{status}");
    assert_eq!(status["runner_settings"]["sandbox"]["kind"], "container");
    assert_eq!(started.count_runner_requests(), 0);
    let Ok(runners) = runners else {
        panic!("the runners are listed");
    };
    assert_eq!(runners["this_device_problem"], json!(expected));
    assert_eq!(
        runners["this_device_settings"]["sandbox"]["kind"],
        "container"
    );
}

#[test]
fn a_stopped_engine_keeps_the_runner_from_claiming_and_says_start_it() {
    let started = start_container_runner(STOPPED_ENGINE);

    std::thread::sleep(QUIET_PERIOD);
    let status = started.read_status();

    let expected = "Docker is not running — start Docker and wait until \
                    it is ready";
    assert_eq!(status["runner_problem"], json!(expected), "{status}");
    assert_eq!(started.count_runner_requests(), 0);
}

#[test]
fn a_present_image_lets_the_runner_start() {
    let started = start_container_runner(READY_ENGINE);

    let announced = wait_for(HEARTBEAT_LIMIT, "a heartbeat", || {
        Ok((started.count_runner_requests() > 0).then_some(()))
    });
    let status = started.read_status();

    assert_eq!(announced, Ok(()));
    assert_eq!(status["runner_problem"], Value::Null, "{status}");
}
