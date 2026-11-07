use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    DESK_CASES, NOT_STARTED_HERE, PairingEnding, REJECTED_STATE,
    open_desk_or_panic, read_approver_words, read_join_state,
    read_joiner_words, read_request,
};
use crate::meddling_server::{EndingAnswer, REFUSED_ENDING_MESSAGE};
use crate::support::test_device::fail;

const MOST_READS: usize = 2;

#[test]
fn test_handle_pairing_command_property_a_refused_cancel_forgets_the_code() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&(0..=MOST_READS), |reads_before| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        for _ in 0..reads_before {
            read_request(&desk.approver, &code).map_err(fail)?;
        }

        desk.server.answer_endings(EndingAnswer::Refused);
        let cancelled = desk.end(&desk.approver, PairingEnding::Cancel, &code);
        desk.reset_meddling();
        let read_after = read_request(&desk.approver, &code);
        let approved_after = desk.approve(&desk.approver, &code);

        let refusal = cancelled.err().unwrap_or_default();
        prop_assert!(refusal.contains(REFUSED_ENDING_MESSAGE), "{}", refusal);
        prop_assert_eq!(read_after, Err(NOT_STARTED_HERE.to_owned()));
        prop_assert_eq!(approved_after, Err(NOT_STARTED_HERE.to_owned()));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_pairing_command_property_a_refused_cancel_keeps_other_codes() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&any::<bool>(), |cancels_the_older| {
        desk.reset_meddling();
        let older = desk.start_and_join().map_err(fail)?;
        let newer = desk.start_and_join().map_err(fail)?;
        let (refused, kept) = if cancels_the_older {
            (older, newer)
        } else {
            (newer, older)
        };

        desk.server.answer_endings(EndingAnswer::Refused);
        let refused_code = refused.session["code"].clone();
        let cancelled =
            desk.end(&desk.approver, PairingEnding::Cancel, &refused_code);
        desk.reset_meddling();
        let kept_code = kept.session["code"].clone();
        let kept_words =
            read_approver_words(&desk.approver, &kept_code).map_err(fail)?;
        let joiner_words = read_joiner_words(&kept.joiner).map_err(fail)?;

        prop_assert!(cancelled.is_err(), "{:?}", cancelled);
        prop_assert_eq!(kept_words, joiner_words);
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_pairing_command_property_a_refused_cancel_can_be_retried() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |refusal_count| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        desk.server.answer_endings(EndingAnswer::Refused);
        for _ in 0..refusal_count {
            let refused =
                desk.end(&desk.approver, PairingEnding::Cancel, &code);
            prop_assert!(refused.is_err(), "{:?}", refused);
        }
        desk.reset_meddling();
        let retried = desk.end(&desk.approver, PairingEnding::Cancel, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(retried, Ok(Value::Null));
        prop_assert_eq!(join_state, json!(REJECTED_STATE));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}
