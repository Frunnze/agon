use std::time::{Duration, Instant};

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, ApproverDesk, read_approver_words, read_join_state,
    read_joiner_words, read_status_problem, start_pairing,
};
use crate::slow_board::{SilentBoardDevice, SilentBoardProxy};
use crate::support::test_device::fail;

const BOARD_CASES: u32 = 2;
const MOST_STARTS: usize = 2;
const LONGEST_CODE_WAIT: Duration = Duration::from_secs(12);
const RENDEZVOUS_PROBLEM_START: &str =
    "the code could not be published or looked up: ";

fn open_silent_desk(
    proxy: &SilentBoardProxy,
) -> Result<ApproverDesk<SilentBoardDevice>, String> {
    let device = SilentBoardDevice::start(proxy)?;
    ApproverDesk::open_with(device)
}

fn read_reply_problem(session: &Value) -> String {
    let reply_problem = session["rendezvous_problem"].as_str();
    reply_problem.unwrap_or_default().to_owned()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(BOARD_CASES))]

    #[test]
    fn test_announce_code_property_a_silent_board_never_holds_the_code(
        start_count in 1..=MOST_STARTS,
    ) {
        let proxy = SilentBoardProxy::start().map_err(fail)?;
        let desk = open_silent_desk(&proxy).map_err(fail)?;

        for _ in 0..start_count {
            let started_at = Instant::now();
            let session = start_pairing(&desk.approver).map_err(fail)?;
            let waited = started_at.elapsed();

            let reply_problem = read_reply_problem(&session);
            prop_assert!(waited < LONGEST_CODE_WAIT, "{:?}", waited);
            prop_assert!(session["display_code"].is_string());
            prop_assert!(
                reply_problem.starts_with(RENDEZVOUS_PROBLEM_START),
                "{}",
                reply_problem
            );
        }
    }

    #[test]
    fn test_announce_code_property_a_silent_board_is_the_status_problem(
        start_count in 1..=MOST_STARTS,
    ) {
        let proxy = SilentBoardProxy::start().map_err(fail)?;
        let desk = open_silent_desk(&proxy).map_err(fail)?;
        let tunnels_before = proxy.count_board_tunnels().map_err(fail)?;

        for _ in 0..start_count {
            let session = start_pairing(&desk.approver).map_err(fail)?;
            let status_problem =
                read_status_problem(&desk.approver).map_err(fail)?;

            let reply_problem = read_reply_problem(&session);
            prop_assert_eq!(status_problem, json!(reply_problem));
        }
        let tunnels_after = proxy.count_board_tunnels().map_err(fail)?;

        prop_assert_eq!(tunnels_before, 0);
        prop_assert!(tunnels_after >= start_count, "{}", tunnels_after);
    }

    #[test]
    fn test_announce_code_property_a_silent_board_never_blocks_pairing(
        reads_before_approval in 1..=MOST_STARTS,
    ) {
        let proxy = SilentBoardProxy::start().map_err(fail)?;
        let desk = open_silent_desk(&proxy).map_err(fail)?;
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

        prop_assert_eq!(approver_words, joiner_words);
        prop_assert_eq!(approved, Ok(Value::Null));
        prop_assert_eq!(join_state, json!(APPROVED_STATE));
    }
}
