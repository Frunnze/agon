use std::collections::VecDeque;
use std::future::ready;
use std::time::Duration;

use orchestration_p2p::board_retry::{
    BOARD_RETRY_PAUSES, is_transient_board_problem,
    retry_transient_board_problems,
};
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::record_board::RecordFields;
use proptest::prelude::*;
use tokio::runtime::{Builder, Runtime};
use tokio::time::Instant;

const BOARD_ATTEMPT_LIMIT: usize = BOARD_RETRY_PAUSES.len() + 1;
const MOST_EXTRA_FAILURES: usize = 6;
const MOST_STORED_FIELDS: usize = 4;
const TOO_MANY_REQUESTS: u16 = 429;
const FIRST_SERVER_ERROR: u16 = 500;
const LAST_SERVER_ERROR: u16 = 599;

#[derive(Debug)]
struct FlakyBoard {
    scripted_failures: VecDeque<PeerError>,
    stored_fields: RecordFields,
    attempts: usize,
}

impl FlakyBoard {
    fn failing_first_with(
        scripted_failures: Vec<PeerError>,
        stored_fields: RecordFields,
    ) -> Self {
        Self {
            scripted_failures: scripted_failures.into(),
            stored_fields,
            attempts: 0,
        }
    }

    fn answer(&mut self) -> Result<RecordFields, PeerError> {
        self.attempts += 1;
        match self.scripted_failures.pop_front() {
            Some(problem) => Err(problem),
            None => Ok(self.stored_fields.clone()),
        }
    }
}

#[derive(Debug)]
struct RetryRecord {
    outcome: Result<RecordFields, String>,
    attempts: usize,
    waited: Duration,
}

fn paused_runtime() -> Result<Runtime, TestCaseError> {
    Builder::new_current_thread()
        .enable_time()
        .start_paused(true)
        .build()
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

fn retry_against(mut board: FlakyBoard) -> Result<RetryRecord, TestCaseError> {
    let runtime = paused_runtime()?;
    let started = runtime.block_on(async { Instant::now() });

    let outcome = runtime
        .block_on(retry_transient_board_problems(|| ready(board.answer())));

    let waited = runtime.block_on(async { started.elapsed() });
    Ok(RetryRecord {
        outcome: outcome.map_err(|problem| problem.to_string()),
        attempts: board.attempts,
        waited,
    })
}

fn total_pause_before(attempt_count: usize) -> Duration {
    let mut total_pause = Duration::ZERO;
    for pause in BOARD_RETRY_PAUSES.iter().take(attempt_count - 1) {
        total_pause += *pause;
    }
    total_pause
}

fn transient_board_problem() -> impl Strategy<Value = PeerError> {
    prop_oneof![
        "[a-z ]{1,20}".prop_map(PeerError::RecordBoardUnreachable),
        Just(TOO_MANY_REQUESTS).prop_map(PeerError::RecordRefused),
        (FIRST_SERVER_ERROR..=LAST_SERVER_ERROR)
            .prop_map(PeerError::RecordRefused),
    ]
}

fn permanent_board_problem() -> impl Strategy<Value = PeerError> {
    prop_oneof![
        (400_u16..TOO_MANY_REQUESTS).prop_map(PeerError::RecordRefused),
        (TOO_MANY_REQUESTS + 1..FIRST_SERVER_ERROR)
            .prop_map(PeerError::RecordRefused),
        "[a-z ]{1,20}".prop_map(PeerError::RecordNotBuilt),
        "[a-z ]{1,20}".prop_map(PeerError::UnreadableRecord),
    ]
}

fn stored_fields() -> impl Strategy<Value = RecordFields> {
    proptest::collection::vec("[a-z]{1,8}=[a-z ]{0,8}", 0..MOST_STORED_FIELDS)
}

fn failures_within_the_limit() -> impl Strategy<Value = Vec<PeerError>> {
    let within_the_limit = 0..BOARD_ATTEMPT_LIMIT;
    proptest::collection::vec(transient_board_problem(), within_the_limit)
}

fn failures_past_the_limit() -> impl Strategy<Value = Vec<PeerError>> {
    let most_failures = BOARD_ATTEMPT_LIMIT + MOST_EXTRA_FAILURES;
    proptest::collection::vec(
        transient_board_problem(),
        BOARD_ATTEMPT_LIMIT..most_failures,
    )
}

#[test]
fn an_unreachable_board_is_transient_and_a_bad_record_is_not() {
    let timed_out = PeerError::RecordBoardUnreachable("timed out".to_owned());
    let rate_limited = PeerError::RecordRefused(TOO_MANY_REQUESTS);
    let unavailable = PeerError::RecordRefused(503);
    let not_found = PeerError::RecordRefused(404);
    let oversized = PeerError::RecordNotBuilt("too long".to_owned());
    let forged = PeerError::UnreadableRecord("bad signature".to_owned());

    assert!(is_transient_board_problem(&timed_out));
    assert!(is_transient_board_problem(&rate_limited));
    assert!(is_transient_board_problem(&unavailable));
    assert!(!is_transient_board_problem(&not_found));
    assert!(!is_transient_board_problem(&oversized));
    assert!(!is_transient_board_problem(&forged));
}

#[test]
fn a_board_that_fails_once_answers_on_the_second_attempt() {
    let hiccup = PeerError::RecordBoardUnreachable("reset".to_owned());
    let fields = vec!["direct=1.2.3.4:5".to_owned()];
    let board = FlakyBoard::failing_first_with(vec![hiccup], fields.clone());

    let Ok(record) = retry_against(board) else {
        panic!("a paused runtime is built");
    };

    assert_eq!(record.outcome, Ok(fields));
    assert_eq!(record.attempts, 2);
    assert_eq!(record.waited, BOARD_RETRY_PAUSES[0]);
}

proptest! {
    #[test]
    fn test_is_transient_board_problem_property_only_429_and_5xx_retry(
        status in any::<u16>(),
    ) {
        let is_server_error =
            (FIRST_SERVER_ERROR..=LAST_SERVER_ERROR).contains(&status);
        let is_rate_limited = status == TOO_MANY_REQUESTS;

        let refusal = PeerError::RecordRefused(status);

        prop_assert_eq!(
            is_transient_board_problem(&refusal),
            is_server_error || is_rate_limited
        );
    }

    #[test]
    fn test_retry_transient_board_problems_property_succeeds_within_limit(
        failures in failures_within_the_limit(),
        fields in stored_fields(),
    ) {
        let failure_count = failures.len();
        let board = FlakyBoard::failing_first_with(failures, fields.clone());

        let record = retry_against(board)?;

        prop_assert_eq!(record.outcome, Ok(fields));
        prop_assert_eq!(record.attempts, failure_count + 1);
        prop_assert_eq!(record.waited, total_pause_before(failure_count + 1));
    }

    #[test]
    fn test_retry_transient_board_problems_property_gives_up_after_limit(
        failures in failures_past_the_limit(),
        fields in stored_fields(),
    ) {
        let last_tried_problem = failures[BOARD_ATTEMPT_LIMIT - 1].to_string();
        let board = FlakyBoard::failing_first_with(failures, fields);

        let record = retry_against(board)?;

        prop_assert_eq!(record.outcome, Err(last_tried_problem));
        prop_assert_eq!(record.attempts, BOARD_ATTEMPT_LIMIT);
        prop_assert_eq!(
            record.waited,
            total_pause_before(BOARD_ATTEMPT_LIMIT)
        );
    }

    #[test]
    fn test_retry_transient_board_problems_property_never_retries_permanent(
        transient_prefix in failures_within_the_limit(),
        permanent_problem in permanent_board_problem(),
        fields in stored_fields(),
    ) {
        let attempts_until_permanent = transient_prefix.len() + 1;
        let expected_problem = permanent_problem.to_string();
        let mut failures = transient_prefix;
        failures.push(permanent_problem);
        let board = FlakyBoard::failing_first_with(failures, fields);

        let record = retry_against(board)?;

        prop_assert_eq!(record.outcome, Err(expected_problem));
        prop_assert_eq!(record.attempts, attempts_until_permanent);
        prop_assert_eq!(
            record.waited,
            total_pause_before(attempts_until_permanent)
        );
    }
}
