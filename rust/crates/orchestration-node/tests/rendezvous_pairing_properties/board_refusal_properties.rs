use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, ApproverDesk, PairingEnding, read_approver_words,
    read_join_state, read_joiner_words, read_status_problem, start_pairing,
};
use crate::board_refusal::{
    ProxiedDevice, RefusingProxy, count_attempts_per_publish,
};
use crate::support::test_device::fail;

const BOARD_CASES: u32 = 2;
const MOST_STARTS: usize = 2;
const RENDEZVOUS_PROBLEM_START: &str =
    "the code could not be published or looked up: ";

fn open_proxied_desk(
    proxy: &RefusingProxy,
) -> Result<ApproverDesk<ProxiedDevice>, String> {
    let device = ProxiedDevice::start(proxy)?;
    ApproverDesk::open_with(device)
}

fn read_reply_problem(session: &Value) -> String {
    let reply_problem = session["rendezvous_problem"].as_str();
    reply_problem.unwrap_or_default().to_owned()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(BOARD_CASES))]

    #[test]
    fn test_find_public_server_address_property_every_start_asks_the_board(
        start_count in 1..=MOST_STARTS,
    ) {
        let proxy = RefusingProxy::start().map_err(fail)?;
        let desk = open_proxied_desk(&proxy).map_err(fail)?;
        let attempts_before = proxy.count_board_attempts().map_err(fail)?;

        for _ in 0..start_count {
            start_pairing(&desk.approver).map_err(fail)?;
        }
        let attempts_after = proxy.count_board_attempts().map_err(fail)?;

        prop_assert_eq!(attempts_before, 0);
        prop_assert_eq!(
            attempts_after,
            start_count * count_attempts_per_publish()
        );
    }

    #[test]
    fn test_publish_server_for_code_property_a_refused_board_is_named(
        start_count in 1..=MOST_STARTS,
    ) {
        let proxy = RefusingProxy::start().map_err(fail)?;
        let desk = open_proxied_desk(&proxy).map_err(fail)?;

        for _ in 0..start_count {
            let session = start_pairing(&desk.approver).map_err(fail)?;
            let status_problem =
                read_status_problem(&desk.approver).map_err(fail)?;

            let reply_problem = read_reply_problem(&session);
            prop_assert!(
                reply_problem.starts_with(RENDEZVOUS_PROBLEM_START),
                "{}",
                reply_problem
            );
            prop_assert_eq!(status_problem, json!(reply_problem));
        }
    }

    #[test]
    fn test_publish_server_for_code_property_a_refusal_never_blocks_pairing(
        reads_before_approval in 1..=MOST_STARTS,
    ) {
        let proxy = RefusingProxy::start().map_err(fail)?;
        let desk = open_proxied_desk(&proxy).map_err(fail)?;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        let mut approver_words = Value::Null;
        for _ in 0..reads_before_approval {
            approver_words =
                read_approver_words(&desk.approver, &code).map_err(fail)?;
        }
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;
        let approved = desk.approve(&desk.approver, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        let reply_problem = read_reply_problem(&joined.session);
        prop_assert!(reply_problem.starts_with(RENDEZVOUS_PROBLEM_START));
        prop_assert_eq!(approver_words, joiner_words);
        prop_assert_eq!(approved, Ok(Value::Null));
        prop_assert_eq!(join_state, json!(APPROVED_STATE));
    }

    #[test]
    fn test_withdraw_when_published_property_a_failed_code_is_never_withdrawn(
        start_count in 1..=MOST_STARTS,
    ) {
        let proxy = RefusingProxy::start().map_err(fail)?;
        let desk = open_proxied_desk(&proxy).map_err(fail)?;
        let mut codes = Vec::new();
        for _ in 0..start_count {
            let session = start_pairing(&desk.approver).map_err(fail)?;
            codes.push(session["code"].clone());
        }
        let attempts_after_starts =
            proxy.count_board_attempts().map_err(fail)?;
        let problem_after_starts =
            read_status_problem(&desk.approver).map_err(fail)?;
        let problem_text = problem_after_starts.as_str().unwrap_or_default();

        for code in &codes {
            let cancelled =
                desk.end(&desk.approver, PairingEnding::Cancel, code);
            prop_assert_eq!(cancelled, Ok(Value::Null));
        }
        let attempts_after_cancels =
            proxy.count_board_attempts().map_err(fail)?;
        let problem_after_cancels =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(attempts_after_cancels, attempts_after_starts);
        prop_assert!(problem_text.starts_with(RENDEZVOUS_PROBLEM_START));
        prop_assert_eq!(problem_after_cancels, Value::Null);
    }
}
