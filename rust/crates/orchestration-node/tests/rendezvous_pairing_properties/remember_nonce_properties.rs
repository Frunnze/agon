use std::collections::BTreeSet;

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, JoinedPairing, NOT_STARTED_HERE, count_words,
    open_desk_or_panic, read_approver_words, read_joiner_words, read_request,
    start_pairing,
};
use crate::support::test_device::fail;

const WORD_COUNT: usize = 4;
const NONCE_LENGTH: usize = 32;
const LARGEST_OPEN_CODES: usize = 3;
const LARGEST_READS_BEFORE_RESTART: usize = 2;

fn shuffled_positions(open_codes: usize) -> impl Strategy<Value = Vec<usize>> {
    let positions: Vec<usize> = (0..open_codes).collect();
    Just(positions).prop_shuffle()
}

fn join_orders() -> impl Strategy<Value = Vec<usize>> {
    (1..=LARGEST_OPEN_CODES).prop_flat_map(shuffled_positions)
}

fn start_and_join_in_order(
    desk: &ApproverDesk,
    join_order: &[usize],
) -> Result<Vec<JoinedPairing>, String> {
    let mut sessions = Vec::new();
    for _ in join_order {
        sessions.push(start_pairing(&desk.approver)?);
    }
    let mut joined_pairings = Vec::new();
    for position in join_order {
        let session = sessions[*position].clone();
        let joiner = desk.join(&session)?;
        joined_pairings.push(JoinedPairing { session, joiner });
    }
    Ok(joined_pairings)
}

#[test]
fn test_remember_nonce_property_every_open_code_keeps_its_own_nonce() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&join_orders(), |join_order| {
        let joined_pairings =
            start_and_join_in_order(&desk, &join_order).map_err(fail)?;

        for joined in &joined_pairings {
            let code = &joined.session["code"];
            let approver_words =
                read_approver_words(&desk.approver, code).map_err(fail)?;
            let joiner_words =
                read_joiner_words(&joined.joiner).map_err(fail)?;

            prop_assert_eq!(count_words(&approver_words), WORD_COUNT);
            prop_assert_eq!(&approver_words, &joiner_words);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_remember_nonce_property_each_code_reveals_a_fresh_nonce() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&join_orders(), |join_order| {
        let earlier_reveals = desk.server.list_revealed_nonces().len();
        let joined_pairings =
            start_and_join_in_order(&desk, &join_order).map_err(fail)?;
        for joined in &joined_pairings {
            read_request(&desk.approver, &joined.session["code"])
                .map_err(fail)?;
        }

        let revealed_nonces = desk.server.list_revealed_nonces();
        let case_reveals = &revealed_nonces[earlier_reveals..];
        let mut distinct_nonces = BTreeSet::new();
        for revealed_nonce in case_reveals {
            let nonce_length = revealed_nonce.as_array().map(Vec::len);
            prop_assert_eq!(nonce_length, Some(NONCE_LENGTH));
            distinct_nonces.insert(revealed_nonce.to_string());
        }
        prop_assert_eq!(case_reveals.len(), join_order.len());
        prop_assert_eq!(distinct_nonces.len(), join_order.len());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_remember_nonce_property_a_restart_forgets_every_nonce(
        reads_before_restart in 0..=LARGEST_READS_BEFORE_RESTART,
    ) {
        let mut desk = ApproverDesk::open().map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        for _ in 0..reads_before_restart {
            read_request(&desk.approver, &code).map_err(fail)?;
        }

        desk.approver.restart().map_err(fail)?;
        let read_after_restart = read_request(&desk.approver, &code);

        prop_assert_eq!(read_after_restart, Err(NOT_STARTED_HERE.to_owned()));
    }
}
