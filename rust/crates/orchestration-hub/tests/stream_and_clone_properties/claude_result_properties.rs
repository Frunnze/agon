use orchestration_hub::agent_event::AgentEvent;
use proptest::prelude::*;
use serde_json::json;

use crate::claude_lines::parse_claude;
use crate::stream_support::UNKNOWN_FAILURE_REASON;

const SUCCESS_SUBTYPE: &str = "success";
const BLANK_TEXTS: [&str; 4] = ["", " ", "\n\t", "\u{a0} \u{2003}"];

fn result_line(
    subtype: Option<&str>,
    is_error: Option<bool>,
    result: Option<&str>,
) -> String {
    let mut line = json!({"type": "result", "session_id": "5f0c3e2a"});
    if let Some(subtype) = subtype {
        line["subtype"] = json!(subtype);
    }
    if let Some(is_error) = is_error {
        line["is_error"] = json!(is_error);
    }
    if let Some(result) = result {
        line["result"] = json!(result);
    }
    line.to_string()
}

fn any_error_subtype() -> impl Strategy<Value = String> {
    ("[ \t]{0,2}", "error_[a-z_]{1,16}", "[ \t]{0,2}")
        .prop_map(|(before, name, after)| format!("{before}{name}{after}"))
}

fn any_missing_result() -> impl Strategy<Value = Option<&'static str>> {
    prop_oneof![
        Just(None),
        proptest::sample::select(BLANK_TEXTS.to_vec()).prop_map(Some),
    ]
}

fn has_text(text: &str) -> bool {
    !text.trim().is_empty()
}

proptest! {
    #[test]
    fn test_describe_result_property_success_finishes_unless_an_error(
        is_error in proptest::option::of(any::<bool>()),
        result in proptest::option::of(any::<String>()),
    ) {
        let result = result.as_deref();
        let line = result_line(Some(SUCCESS_SUBTYPE), is_error, result);

        let agent_events = parse_claude(&line);

        let has_failed = is_error == Some(true);
        let is_finished = agent_events == vec![AgentEvent::Finished];
        prop_assert_eq!(is_finished, !has_failed);
        prop_assert_eq!(agent_events.len(), 1);
    }

    #[test]
    fn test_describe_result_property_reason_prefers_the_result_text(
        subtype in proptest::option::of(any_error_subtype()),
        result in any::<String>().prop_filter("text", |text| has_text(text)),
        padding in "[ \n\t]{0,3}",
    ) {
        let padded_result = format!("{padding}{result}{padding}");
        let subtype = subtype.as_deref();
        let line = result_line(subtype, Some(true), Some(&padded_result));

        let agent_events = parse_claude(&line);

        let expected = AgentEvent::Failed(result.trim().to_owned());
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_result_property_reason_falls_back_to_the_subtype(
        subtype in proptest::option::of(any_error_subtype()),
        result in any_missing_result(),
        is_error in proptest::option::of(any::<bool>()),
    ) {
        let line = result_line(subtype.as_deref(), is_error, result);

        let agent_events = parse_claude(&line);

        let reason = subtype
            .as_deref()
            .map_or(UNKNOWN_FAILURE_REASON, str::trim);
        let expected = AgentEvent::Failed(reason.to_owned());
        prop_assert_eq!(agent_events, vec![expected]);
    }
}
