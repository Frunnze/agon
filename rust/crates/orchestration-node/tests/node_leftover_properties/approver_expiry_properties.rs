use std::thread;
use std::time::Duration;

use proptest::prelude::*;
use proptest::sample::select;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};

use crate::approver_desk::{
    NOT_STARTED_HERE, WAITING_STATE, count_words, read_approver_words,
    read_join_state, read_joiner_words, read_request,
};
use crate::short_session_server::{
    SESSION_LIFETIMES, SHORT_SESSION_LIFETIME, SessionLifetime,
    ShortSessionServer,
};
use crate::support::pairing_steps::join_at_address;
use crate::support::test_device::{TestDevice, fail, read_text};

const EXPIRY_CASES: u32 = 3;
const EXPIRY_MARGIN: Duration = Duration::from_millis(300);
const MOST_CODES: usize = 3;
const WORD_COUNT: usize = 4;

#[derive(Debug)]
struct ExpiryDesk {
    server: ShortSessionServer,
    approver: TestDevice,
    account: Value,
}

#[derive(Debug)]
struct ShownCode {
    code: Value,
    joiner: TestDevice,
    lifetime: SessionLifetime,
}

impl ExpiryDesk {
    fn open() -> Result<Self, TestCaseError> {
        let server = ShortSessionServer::start().map_err(fail)?;
        let approver = TestDevice::start().map_err(fail)?;
        let account_command =
            server.build_create_account_command().map_err(fail)?;
        let account = approver.run(&account_command).map_err(fail)?;
        Ok(Self {
            server,
            approver,
            account,
        })
    }

    fn show_and_join(
        &self,
        lifetime: SessionLifetime,
    ) -> Result<ShownCode, TestCaseError> {
        let session = self
            .server
            .start_pairing_lasting(&self.approver, lifetime)
            .map_err(fail)?;
        let display_code =
            read_text(&session, "/display_code").map_err(fail)?;
        let joiner = TestDevice::start().map_err(fail)?;
        join_at_address(&joiner, &self.server.address, &display_code)
            .map_err(fail)?;
        Ok(ShownCode {
            code: session["code"].clone(),
            joiner,
            lifetime,
        })
    }

    fn start_pairing(&self) -> Result<Value, TestCaseError> {
        let command = json!({ "command": "start_pairing" });
        self.approver.run(&command).map_err(fail)
    }

    fn approve(&self, code: &Value) -> Result<Value, String> {
        self.approver.run(&json!({
            "command": "approve_pairing",
            "code": code,
            "workspace_ids": [self.account["workspaces"][0]["id"]],
        }))
    }
}

fn wait_past_short_lifetime() {
    thread::sleep(SHORT_SESSION_LIFETIME + EXPIRY_MARGIN);
}

fn lifetime_choices() -> impl Strategy<Value = Vec<SessionLifetime>> {
    let lifetime = select(SESSION_LIFETIMES.to_vec());
    prop::collection::vec(lifetime, 1..=MOST_CODES)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(EXPIRY_CASES))]

    #[test]
    fn test_remember_nonce_property_a_new_start_keeps_only_live_codes(
        lifetimes in lifetime_choices(),
    ) {
        let desk = ExpiryDesk::open()?;
        let mut shown_codes = Vec::new();
        for lifetime in lifetimes {
            shown_codes.push(desk.show_and_join(lifetime)?);
        }
        wait_past_short_lifetime();

        desk.start_pairing()?;

        for shown in &shown_codes {
            let approver_words =
                read_approver_words(&desk.approver, &shown.code);
            if shown.lifetime == SessionLifetime::Short {
                prop_assert_eq!(
                    approver_words,
                    Err(NOT_STARTED_HERE.to_owned())
                );
            } else {
                let approver_words = approver_words.map_err(fail)?;
                let joiner_words =
                    read_joiner_words(&shown.joiner).map_err(fail)?;
                prop_assert_eq!(count_words(&approver_words), WORD_COUNT);
                prop_assert_eq!(approver_words, joiner_words);
            }
        }
    }

    #[test]
    fn test_remember_nonce_property_a_forgotten_code_cannot_be_approved(
        later_starts in 1_usize..3,
    ) {
        let desk = ExpiryDesk::open()?;
        let shown = desk.show_and_join(SessionLifetime::Short)?;
        wait_past_short_lifetime();
        for _ in 0..later_starts {
            desk.start_pairing()?;
        }

        let approved = desk.approve(&shown.code);
        let join_state = read_join_state(&shown.joiner).map_err(fail)?;

        prop_assert_eq!(approved, Err(NOT_STARTED_HERE.to_owned()));
        prop_assert_eq!(join_state, json!(WAITING_STATE));
    }

    #[test]
    fn test_remember_nonce_property_a_live_code_outlasts_later_starts(
        read_count in 1_usize..4,
    ) {
        let desk = ExpiryDesk::open()?;
        let shown = desk.show_and_join(SessionLifetime::Normal)?;
        wait_past_short_lifetime();

        let mut every_read = Vec::new();
        for _ in 0..read_count {
            every_read.push(read_request(&desk.approver, &shown.code));
        }
        desk.start_pairing()?;
        let approved = desk.approve(&shown.code);

        for read in every_read {
            prop_assert!(read.is_ok(), "{:?}", read);
        }
        prop_assert_eq!(approved, Ok(Value::Null));
    }
}
