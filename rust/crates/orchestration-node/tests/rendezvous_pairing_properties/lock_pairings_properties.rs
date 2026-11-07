use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::Value;

use crate::approver_desk::{
    DESK_CASES, NOT_STARTED_HERE, open_desk_or_panic, pairing_endings,
    read_approver_words, read_joiner_words, read_request, start_pairing,
};
use crate::at_once::{run_at_once, run_both_at_once};
use crate::meddling_server::EndingAnswer;
use crate::support::test_device::fail;

const FEWEST_THREADS: usize = 2;
const MOST_THREADS: usize = 4;

#[test]
fn test_lock_pairings_property_codes_started_at_once_keep_their_nonces() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));
    let thread_counts = FEWEST_THREADS..=MOST_THREADS;

    let outcome = runner.run(&thread_counts, |thread_count| {
        let starting = || start_pairing(&desk.approver);
        let started = run_at_once(thread_count, &starting);

        for session in started {
            let session = session.map_err(fail)?;
            let joiner = desk.join(&session).map_err(fail)?;
            let approver_words =
                read_approver_words(&desk.approver, &session["code"])
                    .map_err(fail)?;
            let joiner_words = read_joiner_words(&joiner).map_err(fail)?;
            prop_assert_eq!(approver_words, joiner_words);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_lock_pairings_property_reads_at_once_show_one_transcript() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));
    let thread_counts = FEWEST_THREADS..=MOST_THREADS;

    let outcome = runner.run(&thread_counts, |thread_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        let reading = || read_request(&desk.approver, &code);
        let requests = run_at_once(thread_count, &reading);
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;

        for request in requests {
            let request = request.map_err(fail)?;
            let words = &request["joining"]["fingerprint_words"];
            prop_assert_eq!(words, &joiner_words);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_lock_pairings_property_ending_one_code_while_reading_another() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        desk.reset_meddling();
        let ended_pairing = desk.start_and_join().map_err(fail)?;
        let read_pairing = desk.start_and_join().map_err(fail)?;
        let ended_code = ended_pairing.session["code"].clone();
        let read_code = read_pairing.session["code"].clone();
        read_request(&desk.approver, &ended_code).map_err(fail)?;
        desk.server.answer_endings(EndingAnswer::Swallowed);

        let ending_task = || desk.end(&desk.approver, ending, &ended_code);
        let reading_task = || read_approver_words(&desk.approver, &read_code);
        let (ended, read_words) =
            run_both_at_once(&ending_task, &reading_task);
        desk.reset_meddling();
        let joiner_words =
            read_joiner_words(&read_pairing.joiner).map_err(fail)?;
        let ended_read = read_request(&desk.approver, &ended_code);

        prop_assert_eq!(ended, Ok(Value::Null));
        prop_assert_eq!(read_words, Ok(joiner_words));
        prop_assert_eq!(ended_read, Err(NOT_STARTED_HERE.to_owned()));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}
