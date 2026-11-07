use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::approver_desk::{
    DESK_CASES, TRANSCRIPT_CHANGED, WAITING_STATE, changing_rewrites,
    joiner_side_rewrites, open_desk_or_panic, read_approver_words,
    read_join_state, read_joiner_words, read_request,
};
use crate::support::test_device::fail;

const FEWEST_READS: usize = 2;
const MOST_READS: usize = 5;
const MOST_MEDDLED_READS: usize = 3;

#[test]
fn test_pin_transcript_property_repeated_reads_show_the_same_words() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&(FEWEST_READS..=MOST_READS), |read_count| {
        let earlier_reveals = desk.server.list_revealed_nonces().len();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        let mut shown_words = Vec::new();
        for _ in 0..read_count {
            let words =
                read_approver_words(&desk.approver, &code).map_err(fail)?;
            shown_words.push(words);
        }
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;
        let case_reveals =
            desk.server.list_revealed_nonces().len() - earlier_reveals;

        for words in &shown_words {
            prop_assert_eq!(words, &joiner_words);
        }
        prop_assert_eq!(case_reveals, 1);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_pin_transcript_property_a_changed_joining_device_is_refused() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&changing_rewrites(), |rewrite| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;

        desk.server.rewrite_joining(Some(rewrite));
        let changed_read = read_request(&desk.approver, &code);
        let changed_approval = desk.approve(&desk.approver, &code);
        desk.reset_meddling();
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(changed_read, Err(TRANSCRIPT_CHANGED.to_owned()));
        prop_assert_eq!(changed_approval, Err(TRANSCRIPT_CHANGED.to_owned()));
        prop_assert_eq!(join_state, json!(WAITING_STATE));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_pin_transcript_property_the_first_shown_device_stays_pinned() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));
    let meddled_reads = (changing_rewrites(), 1..=MOST_MEDDLED_READS);

    let outcome = runner.run(&meddled_reads, |(rewrite, meddled_count)| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let first_words =
            read_approver_words(&desk.approver, &code).map_err(fail)?;

        desk.server.rewrite_joining(Some(rewrite));
        for _ in 0..meddled_count {
            let meddled_read = read_request(&desk.approver, &code);
            prop_assert_eq!(meddled_read, Err(TRANSCRIPT_CHANGED.to_owned()));
        }
        desk.reset_meddling();
        let words_again =
            read_approver_words(&desk.approver, &code).map_err(fail)?;

        prop_assert_eq!(words_again, first_words);
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_pin_transcript_property_a_swapped_first_device_never_matches() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&joiner_side_rewrites(), |rewrite| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        desk.server.rewrite_joining(Some(rewrite));
        let swapped_words =
            read_approver_words(&desk.approver, &code).map_err(fail)?;
        desk.reset_meddling();
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;
        let genuine_read = read_request(&desk.approver, &code);
        let genuine_approval = desk.approve(&desk.approver, &code);

        prop_assert_ne!(swapped_words, joiner_words);
        prop_assert_eq!(genuine_read, Err(TRANSCRIPT_CHANGED.to_owned()));
        prop_assert_eq!(genuine_approval, Err(TRANSCRIPT_CHANGED.to_owned()));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}
