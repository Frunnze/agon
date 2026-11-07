use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, ApproverDesk, DESK_CASES, NOT_STARTED_HERE, WAITING_STATE,
    WORDS_NOT_READY, open_desk_or_panic, read_approver_words, read_join_state,
    read_joiner_words, read_request,
};
use crate::meddling_server::JoiningRewrite;
use crate::support::test_device::{TestDevice, fail, read_text};

const SPELLING_CHOICES: usize = 4;
const SEPARATOR_CHOICES: [&str; 3] = ["", "-", " "];
const CODE_LENGTH: usize = 6;
const ZERO_SPELLINGS: [char; 4] = ['0', 'O', 'o', '0'];
const ONE_SPELLINGS: [char; 4] = ['1', 'I', 'i', 'l'];

type SymbolSpelling = (usize, usize);

fn code_spellings() -> impl Strategy<Value = Vec<SymbolSpelling>> {
    let symbol_spelling = (0..SPELLING_CHOICES, 0..SEPARATOR_CHOICES.len());
    proptest::collection::vec(symbol_spelling, CODE_LENGTH)
}

fn respell_symbol(symbol: char, spelling_choice: usize) -> char {
    match symbol {
        '0' => ZERO_SPELLINGS[spelling_choice],
        '1' => ONE_SPELLINGS[spelling_choice],
        _ if spelling_choice % 2 == 1 => symbol.to_ascii_lowercase(),
        _ => symbol,
    }
}

fn respell_code(canonical_code: &str, spellings: &[SymbolSpelling]) -> String {
    let mut spelled_code = String::new();
    for (symbol, (spelling_choice, separator_choice)) in
        canonical_code.chars().zip(spellings)
    {
        spelled_code.push(respell_symbol(symbol, *spelling_choice));
        spelled_code.push_str(SEPARATOR_CHOICES[*separator_choice]);
    }
    spelled_code
}

fn pair_second_device(desk: &ApproverDesk) -> Result<TestDevice, String> {
    let joined = desk.start_and_join()?;
    let code = &joined.session["code"];
    read_request(&desk.approver, code)?;
    desk.approve(&desk.approver, code)?;
    let join_state = read_join_state(&joined.joiner)?;
    if join_state != json!(APPROVED_STATE) {
        return Err(format!("the second device ended as {join_state}"));
    }
    Ok(joined.joiner)
}

#[test]
fn test_find_approver_nonce_property_another_device_cannot_show_words() {
    let desk = open_desk_or_panic();
    let second_device = pair_second_device(&desk);
    let Ok(second_device) = second_device else {
        panic!("a second device joins the account: {second_device:?}");
    };
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&any::<bool>(), |approver_reads_first| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        if approver_reads_first {
            read_request(&desk.approver, &code).map_err(fail)?;
        }

        let read_elsewhere = read_request(&second_device, &code);
        let approved_elsewhere = desk.approve(&second_device, &code);
        let approver_words =
            read_approver_words(&desk.approver, &code).map_err(fail)?;
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(read_elsewhere, Err(NOT_STARTED_HERE.to_owned()));
        prop_assert_eq!(approved_elsewhere, Err(NOT_STARTED_HERE.to_owned()));
        prop_assert_eq!(approver_words, joiner_words);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_approver_nonce_property_any_spelling_of_the_code_finds_it() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&code_spellings(), |spellings| {
        let joined = desk.start_and_join().map_err(fail)?;
        let canonical_code =
            read_text(&joined.session, "/code").map_err(fail)?;
        let spelled_code = json!(respell_code(&canonical_code, &spellings));

        let spelled_words = read_approver_words(&desk.approver, &spelled_code)
            .map_err(fail)?;
        let canonical_words =
            read_approver_words(&desk.approver, &json!(canonical_code))
                .map_err(fail)?;
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(&spelled_words, &canonical_words);
        prop_assert_eq!(&spelled_words, &joiner_words);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_find_approver_nonce_property_a_restarted_device_cannot_approve(
        approver_reads_first in any::<bool>(),
    ) {
        let mut desk = ApproverDesk::open().map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        if approver_reads_first {
            read_request(&desk.approver, &code).map_err(fail)?;
        }

        desk.approver.restart().map_err(fail)?;
        let approved = desk.approve(&desk.approver, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(approved, Err(NOT_STARTED_HERE.to_owned()));
        prop_assert_eq!(join_state, json!(WAITING_STATE));
    }

    #[test]
    fn test_find_approver_nonce_property_no_nonce_is_needed_before_the_joiner(
        restarts_first in any::<bool>(),
    ) {
        let mut desk = ApproverDesk::open().map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        if restarts_first {
            desk.approver.restart().map_err(fail)?;
        }
        desk.server
            .rewrite_joining(Some(JoiningRewrite::HiddenJoinerNonce));

        let request = read_request(&desk.approver, &code).map_err(fail)?;
        let approved = desk.approve(&desk.approver, &code);

        prop_assert_eq!(&request["joining"], &Value::Null);
        prop_assert_eq!(approved, Err(WORDS_NOT_READY.to_owned()));
    }
}
