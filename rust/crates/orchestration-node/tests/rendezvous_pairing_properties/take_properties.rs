use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::Value;

use crate::approver_desk::{
    DESK_CASES, open_desk_or_panic, pairing_endings, read_approver_words,
    read_join_state, read_joiner_words, read_request, read_status_problem,
};
use crate::support::test_device::fail;

const MOST_READS: usize = 4;

#[test]
fn test_take_property_withdrawing_unpublished_codes_records_nothing() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;

        let ended = desk.end(&desk.approver, ending, &code);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(ended, Ok(Value::Null));
        prop_assert_eq!(status_problem, Value::Null);
        prop_assert_eq!(join_state, ending.expected_join_state());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_take_property_reading_a_joined_request_withdraws_quietly() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        for _ in 0..read_count {
            let approver_words =
                read_approver_words(&desk.approver, &code).map_err(fail)?;
            let joiner_words =
                read_joiner_words(&joined.joiner).map_err(fail)?;
            let status_problem =
                read_status_problem(&desk.approver).map_err(fail)?;

            prop_assert_eq!(approver_words, joiner_words);
            prop_assert_eq!(status_problem, Value::Null);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_take_property_a_second_ending_changes_nothing_here() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));
    let ending_pairs = (pairing_endings(), pairing_endings());

    let outcome = runner.run(&ending_pairs, |(ending, second_ending)| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;
        desk.end(&desk.approver, ending, &code).map_err(fail)?;

        let ended_again = desk.end(&desk.approver, second_ending, &code);
        let status_problem =
            read_status_problem(&desk.approver).map_err(fail)?;
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert!(ended_again.is_err(), "{:?}", ended_again);
        prop_assert_eq!(status_problem, Value::Null);
        prop_assert_eq!(join_state, ending.expected_join_state());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
