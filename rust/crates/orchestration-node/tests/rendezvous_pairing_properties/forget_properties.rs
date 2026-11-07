use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    DESK_CASES, NOT_STARTED_HERE, PairingEnding, WAITING_STATE,
    open_desk_or_panic, pairing_endings, read_approver_words, read_join_state,
    read_joiner_words, read_request,
};
use crate::meddling_server::{EndingAnswer, REFUSED_ENDING_MESSAGE};
use crate::support::test_device::fail;

#[test]
fn test_forget_property_an_ended_pairing_no_longer_shows_words() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;

        desk.server.answer_endings(EndingAnswer::Swallowed);
        let ended = desk.end(&desk.approver, ending, &code);
        let read_after_ending = read_request(&desk.approver, &code);

        prop_assert_eq!(ended, Ok(Value::Null));
        prop_assert_eq!(read_after_ending, Err(NOT_STARTED_HERE.to_owned()));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_forget_property_an_ended_pairing_can_no_longer_be_approved() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        desk.server.answer_endings(EndingAnswer::Swallowed);
        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        desk.server.answer_endings(EndingAnswer::Forwarded);
        let approved_after_ending = desk.approve(&desk.approver, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(
            approved_after_ending,
            Err(NOT_STARTED_HERE.to_owned())
        );
        prop_assert_eq!(join_state, json!(WAITING_STATE));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_forget_property_ending_one_code_keeps_the_others() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        desk.reset_meddling();
        let ended_pairing = desk.start_and_join().map_err(fail)?;
        let kept_pairing = desk.start_and_join().map_err(fail)?;
        let ended_code = ended_pairing.session["code"].clone();
        let kept_code = kept_pairing.session["code"].clone();

        desk.server.answer_endings(EndingAnswer::Swallowed);
        desk.end(&desk.approver, ending, &ended_code)
            .map_err(fail)?;
        desk.reset_meddling();
        let kept_words =
            read_approver_words(&desk.approver, &kept_code).map_err(fail)?;
        let joiner_words =
            read_joiner_words(&kept_pairing.joiner).map_err(fail)?;

        prop_assert_eq!(kept_words, joiner_words);
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

fn answering_endings() -> impl Strategy<Value = PairingEnding> {
    prop_oneof![Just(PairingEnding::Reject), Just(PairingEnding::Approve)]
}

#[test]
fn test_forget_property_a_refused_answer_keeps_the_pairing() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&answering_endings(), |ending| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        desk.server.answer_endings(EndingAnswer::Refused);
        let refused = desk.end(&desk.approver, ending, &code);
        desk.reset_meddling();
        let approver_words =
            read_approver_words(&desk.approver, &code).map_err(fail)?;
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;
        let ended_for_real = desk.end(&desk.approver, ending, &code);

        let refusal = refused.err().unwrap_or_default();
        prop_assert!(refusal.contains(REFUSED_ENDING_MESSAGE), "{}", refusal);
        prop_assert_eq!(approver_words, joiner_words);
        prop_assert_eq!(ended_for_real, Ok(Value::Null));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}
