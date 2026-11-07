use std::time::{Duration, Instant};

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{ApproverDesk, start_pairing};
use crate::command_device::CommandDevice;
use crate::slow_board::{SilentBoardDevice, SilentBoardProxy};
use crate::support::test_device::fail;

const LIMIT_CASES: u32 = 2;
const MOST_STARTS: usize = 2;
const SHORTEST_FAIR_WAIT: Duration = Duration::from_secs(1);
const LONGEST_CODE_WAIT: Duration = Duration::from_secs(12);
const QUICK_ANSWER_LIMIT: Duration = Duration::from_secs(3);
const SILENT_BOARD_START: &str = "the code could not be published or looked \
                                  up: the public record board could not be \
                                  reached: no answer within ";
const SECONDS_END: &str = " seconds";

struct SilentDesk {
    proxy: SilentBoardProxy,
    desk: ApproverDesk<SilentBoardDevice>,
}

fn open_silent_desk_or_panic() -> SilentDesk {
    let Ok(proxy) = SilentBoardProxy::start() else {
        panic!("the silent board proxy starts");
    };
    let device = SilentBoardDevice::start(&proxy);
    let Ok(device) = device else {
        panic!("the device starts behind the proxy: {device:?}");
    };
    let desk = ApproverDesk::open_with(device);
    let Ok(desk) = desk else {
        panic!("the approver desk opens: {desk:?}");
    };
    SilentDesk { proxy, desk }
}

fn read_reply_problem(session: &Value) -> String {
    let reply_problem = session["rendezvous_problem"].as_str();
    reply_problem.unwrap_or_default().to_owned()
}

fn read_waiting_seconds(problem: &str) -> Option<u64> {
    let rest = problem.strip_prefix(SILENT_BOARD_START)?;
    let seconds_text = rest.strip_suffix(SECONDS_END)?;
    seconds_text.parse().ok()
}

#[test]
fn test_publish_within_limit_property_the_board_gets_a_fair_wait() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIMIT_CASES));

    let outcome = runner.run(&(1..=MOST_STARTS), |start_count| {
        for _ in 0..start_count {
            let started_at = Instant::now();
            start_pairing(&silent.desk.approver).map_err(fail)?;
            let waited = started_at.elapsed();

            prop_assert!(waited >= SHORTEST_FAIR_WAIT, "{:?}", waited);
            prop_assert!(waited < LONGEST_CODE_WAIT, "{:?}", waited);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_publish_within_limit_property_the_node_answers_at_once_after() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIMIT_CASES));

    let outcome = runner.run(&(1..=MOST_STARTS), |status_reads| {
        start_pairing(&silent.desk.approver).map_err(fail)?;

        for _ in 0..status_reads {
            let status_command = json!({ "command": "status" });
            let started_at = Instant::now();
            let status = silent.desk.approver.run(&status_command);
            let waited = started_at.elapsed();

            prop_assert!(status.is_ok(), "{:?}", status);
            prop_assert!(waited < QUICK_ANSWER_LIMIT, "{:?}", waited);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_publish_within_limit_property_a_silent_code_is_never_withdrawn() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIMIT_CASES));

    let outcome = runner.run(&any::<bool>(), |is_rejected| {
        let session = start_pairing(&silent.desk.approver).map_err(fail)?;
        let tunnels_before =
            silent.proxy.count_board_tunnels().map_err(fail)?;
        let command_name = if is_rejected {
            "reject_pairing"
        } else {
            "cancel_pairing"
        };
        let ending =
            json!({ "command": command_name, "code": session["code"] });

        let started_at = Instant::now();
        let ended = silent.desk.approver.run(&ending);
        let waited = started_at.elapsed();
        let tunnels_after =
            silent.proxy.count_board_tunnels().map_err(fail)?;

        prop_assert_eq!(ended, Ok(Value::Null));
        prop_assert_eq!(tunnels_after, tunnels_before);
        prop_assert!(waited < SHORTEST_FAIR_WAIT, "{:?}", waited);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_describe_silent_board_property_names_the_limit_in_seconds() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIMIT_CASES));

    let outcome = runner.run(&(1..=MOST_STARTS), |start_count| {
        for _ in 0..start_count {
            let started_at = Instant::now();
            let session =
                start_pairing(&silent.desk.approver).map_err(fail)?;
            let waited = started_at.elapsed();

            let problem = read_reply_problem(&session);
            let seconds = read_waiting_seconds(&problem);
            let Some(seconds) = seconds else {
                return Err(fail(problem));
            };
            prop_assert!(seconds >= 1, "{}", problem);
            prop_assert!(waited.as_secs() >= seconds, "{:?}", waited);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_describe_silent_board_property_every_start_names_the_same() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIMIT_CASES));

    let outcome = runner.run(&(2..=MOST_STARTS + 1), |start_count| {
        let mut problems = Vec::new();
        for _ in 0..start_count {
            let session =
                start_pairing(&silent.desk.approver).map_err(fail)?;
            problems.push(read_reply_problem(&session));
        }

        let first_problem = problems[0].clone();
        prop_assert!(!first_problem.is_empty());
        for problem in &problems {
            prop_assert_eq!(problem, &first_problem);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_describe_silent_board_property_the_status_names_the_newest() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIMIT_CASES));

    let outcome = runner.run(&any::<bool>(), |cancels_the_code| {
        let session = start_pairing(&silent.desk.approver).map_err(fail)?;
        if cancels_the_code {
            let code = &session["code"];
            let cancelling =
                json!({ "command": "cancel_pairing", "code": code });
            silent.desk.approver.run(&cancelling).map_err(fail)?;
        }
        let status_command = json!({ "command": "status" });
        let status =
            silent.desk.approver.run(&status_command).map_err(fail)?;

        let shown = &status["rendezvous_problem"];
        if cancels_the_code {
            prop_assert_eq!(shown, &Value::Null);
        } else {
            prop_assert_eq!(shown, &json!(read_reply_problem(&session)));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
