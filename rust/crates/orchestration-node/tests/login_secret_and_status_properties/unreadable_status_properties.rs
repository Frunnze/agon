use proptest::prelude::*;
use serde_json::{Value, json};

use crate::login_records::{
    CLAUDE_LOGIN_FIELD, CREDENTIAL_KIND_FIELD, LOGGED_IN, LOGIN_RUNNER_CASES,
    NOT_LOGGED_IN, UNKNOWN_LOGIN, answer_status_with, read_status,
    save_api_key, start_nodes,
};

const LOGGED_IN_FIELD: &str = "loggedIn";
const API_KEY_NAME: &str = "api_key";
const MAXIMUM_ANSWERS: usize = 4;

fn is_readable_status_answer(answer: &str) -> bool {
    let Ok(parsed) = serde_json::from_str::<Value>(answer.trim()) else {
        return false;
    };
    parsed.get(LOGGED_IN_FIELD).is_some_and(Value::is_boolean)
}

fn any_unreadable_answer() -> impl Strategy<Value = String> {
    let answer = prop_oneof![
        Just(String::new()),
        "[ \t\r\n]{1,6}",
        "[A-Za-z .:!]{1,60}",
        "\\{[^}]{0,30}",
        "\\[[^\\]]{0,30}",
        Just("{\"loggedIn\": \"yes\"}".to_owned()),
        Just("{\"loggedIn\": null}".to_owned()),
        Just("[true]".to_owned()),
        Just("true".to_owned()),
        "\\PC{1,40}",
    ];
    answer.prop_filter("a readable answer", |text| {
        !is_readable_status_answer(text)
    })
}

fn any_unreadable_answers() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(any_unreadable_answer(), 1..=MAXIMUM_ANSWERS)
}

fn any_api_key() -> impl Strategy<Value = Option<String>> {
    proptest::option::of("sk-ant-api03-[A-Za-z0-9_-]{10,40}")
}

fn any_readable_answer() -> impl Strategy<Value = (bool, String)> {
    let padding = "[ \t\r\n]{0,3}";
    let method = "[a-z.]{0,12}";
    (any::<bool>(), padding, method, "[ \t\r\n]{0,3}").prop_map(
        |(is_logged_in, before, method, after)| {
            let fields = json!({
                LOGGED_IN_FIELD: is_logged_in,
                "authMethod": method,
            });
            (is_logged_in, format!("{before}{fields}{after}"))
        },
    )
}

fn expected_login(is_logged_in: bool) -> &'static str {
    if is_logged_in {
        return LOGGED_IN;
    }
    NOT_LOGGED_IN
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_RUNNER_CASES))]

    #[test]
    fn test_read_agent_login_status_property_unreadable_reads_unknown(
        answers in any_unreadable_answers(),
    ) {
        let nodes = start_nodes()?;

        for answer in answers {
            answer_status_with(&nodes, &answer)?;

            let status = read_status(&nodes)?;

            prop_assert_eq!(
                &status[CLAUDE_LOGIN_FIELD], UNKNOWN_LOGIN, "{:?}", answer
            );
        }
    }

    #[test]
    fn test_read_agent_login_status_property_the_credential_still_shows(
        api_key in any_api_key(),
        answers in any_unreadable_answers(),
    ) {
        let nodes = start_nodes()?;
        let mut expected_credential = Value::Null;
        if let Some(api_key) = &api_key {
            save_api_key(&nodes, api_key)?;
            expected_credential = json!(API_KEY_NAME);
        }

        for answer in answers {
            answer_status_with(&nodes, &answer)?;

            let status = read_status(&nodes)?;

            prop_assert_eq!(
                &status[CREDENTIAL_KIND_FIELD], &expected_credential
            );
        }
    }

    #[test]
    fn test_read_agent_login_status_property_readable_answers_stay_exact(
        unreadable in any_unreadable_answers(),
        readable in proptest::collection::vec(any_readable_answer(), 1..4),
    ) {
        let nodes = start_nodes()?;
        let answers = unreadable.iter().zip(readable.iter());

        for (unreadable_answer, (is_logged_in, readable_answer)) in answers {
            answer_status_with(&nodes, unreadable_answer)?;
            read_status(&nodes)?;
            answer_status_with(&nodes, readable_answer)?;

            let status = read_status(&nodes)?;

            prop_assert_eq!(
                &status[CLAUDE_LOGIN_FIELD], expected_login(*is_logged_in)
            );
        }
    }
}
