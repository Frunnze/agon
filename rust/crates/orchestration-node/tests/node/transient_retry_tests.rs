use std::collections::VecDeque;
use std::future::ready;
use std::time::Duration;

use orchestration_core::approval::ApprovalDecision;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::{
    FIRST_RETRY_DELAY, LONGEST_RETRY_DELAY, is_transient_failure,
    next_retry_delay, retry_transient,
};
use proptest::prelude::*;
use proptest::strategy::LazyJust;
use tokio::runtime::Runtime;
use tokio::time::Instant;

use crate::support::test_device::fail;

const MOST_FAILURES: usize = 12;
const MOST_DELAY_STEPS: usize = 40;

type ScriptedAnswer = Result<ApprovalDecision, NodeError>;

#[derive(Debug)]
struct RetryRecord {
    outcome: Result<ApprovalDecision, String>,
    attempts: usize,
    waited: Duration,
}

fn transient_failure() -> impl Strategy<Value = NodeError> {
    prop_oneof![
        "[a-z ]{1,20}".prop_map(NodeError::ServerUnreachable),
        (500_u16..600).prop_map(|status| NodeError::ServerRejected {
            status,
            message: "the server broke".to_owned(),
        }),
    ]
}

fn transient_failures() -> impl Strategy<Value = Vec<NodeError>> {
    proptest::collection::vec(transient_failure(), 0..MOST_FAILURES)
}

fn definite_failure() -> impl Strategy<Value = NodeError> {
    prop_oneof![
        (400_u16..500).prop_map(|status| NodeError::ServerRejected {
            status,
            message: "the request was refused".to_owned(),
        }),
        "[a-z ]{1,20}".prop_map(NodeError::UntrustedDecision),
        LazyJust::new(|| NodeError::NoAccount),
    ]
}

fn any_decision() -> impl Strategy<Value = ApprovalDecision> {
    prop_oneof![
        Just(ApprovalDecision::Approved),
        Just(ApprovalDecision::Denied),
    ]
}

fn paused_runtime() -> Result<Runtime, TestCaseError> {
    tokio::runtime::Builder::new_current_thread()
        .enable_time()
        .start_paused(true)
        .build()
        .map_err(fail)
}

fn run_script(
    script: Vec<ScriptedAnswer>,
) -> Result<RetryRecord, TestCaseError> {
    let runtime = paused_runtime()?;
    let mut answers: VecDeque<ScriptedAnswer> = script.into();
    let mut attempts = 0;
    let started = runtime.block_on(async { Instant::now() });

    let outcome = runtime.block_on(retry_transient(|| {
        attempts += 1;
        let answer = answers.pop_front().unwrap_or(Err(NodeError::NoAccount));
        ready(answer)
    }));

    let waited = runtime.block_on(async { started.elapsed() });
    Ok(RetryRecord {
        outcome: outcome.map_err(|problem| problem.to_string()),
        attempts,
        waited,
    })
}

fn expected_wait(failure_count: usize) -> Duration {
    let mut total = Duration::ZERO;
    let mut delay = FIRST_RETRY_DELAY;
    for _ in 0..failure_count {
        total += delay;
        delay = next_retry_delay(delay);
    }
    total
}

#[test]
fn connection_failures_and_server_errors_are_transient() {
    let unreachable = NodeError::ServerUnreachable("refused".to_owned());
    let broken = NodeError::ServerRejected {
        status: 503,
        message: "busy".to_owned(),
    };
    let refused = NodeError::ServerRejected {
        status: 404,
        message: "gone".to_owned(),
    };
    let untrusted = NodeError::UntrustedDecision("forged".to_owned());

    assert!(is_transient_failure(&unreachable));
    assert!(is_transient_failure(&broken));
    assert!(!is_transient_failure(&refused));
    assert!(!is_transient_failure(&untrusted));
}

proptest! {
    #[test]
    fn test_retry_transient_property_transient_failures_end_in_the_decision(
        failures in transient_failures(),
        decision in any_decision(),
    ) {
        let failure_count = failures.len();
        let mut script: Vec<ScriptedAnswer> =
            failures.into_iter().map(Err).collect();
        script.push(Ok(decision));

        let record = run_script(script)?;

        prop_assert_eq!(record.outcome, Ok(decision));
        prop_assert_eq!(record.attempts, failure_count + 1);
        prop_assert_eq!(record.waited, expected_wait(failure_count));
    }

    #[test]
    fn test_retry_transient_property_a_definite_failure_stops_at_once(
        failures in transient_failures(),
        definite in definite_failure(),
        decision in any_decision(),
    ) {
        let failure_count = failures.len();
        let expected_problem = definite.to_string();
        let mut script: Vec<ScriptedAnswer> =
            failures.into_iter().map(Err).collect();
        script.push(Err(definite));
        script.push(Ok(decision));

        let record = run_script(script)?;

        prop_assert_eq!(record.outcome, Err(expected_problem));
        prop_assert_eq!(record.attempts, failure_count + 1);
    }

    #[test]
    fn test_next_retry_delay_property_doubles_up_to_the_cap(
        step_count in 0..MOST_DELAY_STEPS,
    ) {
        let mut delay = FIRST_RETRY_DELAY;
        for _ in 0..step_count {
            let next_delay = next_retry_delay(delay);

            prop_assert!(next_delay >= delay);
            prop_assert!(next_delay <= LONGEST_RETRY_DELAY);
            prop_assert_eq!(next_delay, (delay * 2).min(LONGEST_RETRY_DELAY));
            delay = next_delay;
        }
    }
}
