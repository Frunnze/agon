use orchestration_hub::agent_event::AgentEvent;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::gemini_lines::{
    error_event_line, result_line, speech_lines, tool_result_line,
};
use crate::gemini_reading::{any_speech_parts, read_gemini, said_speech};
use crate::log_support::UNICODE_SPACES;
use crate::stream_support::{
    UNKNOWN_AGENT_ERROR, UNKNOWN_FAILURE_REASON, UNKNOWN_TOOL_FAILURE,
};

const SUCCESS_STATUS: &str = "success";
const ERROR_STATUS: &str = "error";

fn any_blank_text() -> impl Strategy<Value = String> {
    let space = proptest::sample::select(UNICODE_SPACES.to_vec());
    vec(space, 0..4).prop_map(|spaces| spaces.into_iter().collect())
}

fn any_given_text() -> impl Strategy<Value = String> {
    prop_oneof![
        any_blank_text(),
        (
            any_blank_text(),
            "[a-zA-Z0-9][a-zA-Z0-9 :]{0,20}",
            any_blank_text()
        )
            .prop_map(|(leading, words, trailing)| {
                format!("{leading}{words}{trailing}")
            }),
    ]
}

fn any_status() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(SUCCESS_STATUS.to_owned()),
        Just(ERROR_STATUS.to_owned()),
        "[a-zA-Z_]{0,10}",
    ]
}

fn expect_first_given(given_texts: &[&str], fallback: &str) -> String {
    for given_text in given_texts {
        if !given_text.trim().is_empty() {
            return given_text.trim().to_owned();
        }
    }
    fallback.to_owned()
}

proptest! {
    #[test]
    fn test_describe_tool_result_property_only_errors_are_reported(
        status in any_status(),
        output in any_given_text(),
        message in any_given_text(),
    ) {
        let line = tool_result_line(&status, Some(&output), Some(&message));

        let agent_events = read_gemini(&[line]);

        let expected = if status == ERROR_STATUS {
            let error = expect_first_given(
                &[&message, &output],
                UNKNOWN_TOOL_FAILURE,
            );
            vec![AgentEvent::ToolFailed(error)]
        } else {
            Vec::new()
        };
        prop_assert_eq!(agent_events, expected);
    }

    #[test]
    fn test_describe_tool_result_property_missing_texts_use_the_default(
        has_output in any::<bool>(),
        blank in any_blank_text(),
    ) {
        let output = has_output.then_some(blank.as_str());

        let agent_events =
            read_gemini(&[tool_result_line(ERROR_STATUS, output, None)]);

        let failure = AgentEvent::ToolFailed(UNKNOWN_TOOL_FAILURE.to_owned());
        prop_assert_eq!(agent_events, vec![failure]);
    }

    #[test]
    fn test_describe_tool_result_property_any_result_ends_the_speech(
        parts in any_speech_parts(),
        status in any_status(),
    ) {
        let mut lines = speech_lines(&parts);
        lines.push(tool_result_line(&status, Some("done"), None));

        let agent_events = read_gemini(&lines);

        let expected_speech = said_speech(&parts);
        prop_assert_eq!(agent_events.first(), expected_speech.first());
    }

    #[test]
    fn test_describe_result_property_only_success_finishes(
        status in any_status(),
        error_type in any_given_text(),
        message in any_given_text(),
    ) {
        let error = Some((error_type.as_str(), message.as_str()));

        let agent_events = read_gemini(&[result_line(&status, error)]);

        let expected = if status == SUCCESS_STATUS {
            AgentEvent::Finished
        } else {
            let reason = expect_first_given(
                &[&message, &error_type],
                UNKNOWN_FAILURE_REASON,
            );
            AgentEvent::Failed(reason)
        };
        prop_assert_eq!(agent_events, vec![expected]);
    }

    #[test]
    fn test_describe_result_property_failures_always_have_a_reason(
        status in "[a-zA-Z_]{0,10}",
        has_error in any::<bool>(),
        blank in any_blank_text(),
    ) {
        prop_assume!(status != SUCCESS_STATUS);
        let error = has_error.then_some((blank.as_str(), blank.as_str()));

        let agent_events = read_gemini(&[result_line(&status, error)]);

        let failure = AgentEvent::Failed(UNKNOWN_FAILURE_REASON.to_owned());
        prop_assert_eq!(agent_events, vec![failure]);
    }

    #[test]
    fn test_describe_result_property_result_follows_the_speech(
        parts in any_speech_parts(),
        status in any_status(),
    ) {
        let mut lines = speech_lines(&parts);
        lines.push(result_line(&status, None));

        let agent_events = read_gemini(&lines);

        let expected_speech = said_speech(&parts);
        prop_assert_eq!(agent_events.len(), expected_speech.len() + 1);
        prop_assert_eq!(agent_events.first(), expected_speech.first());
    }

    #[test]
    fn test_choose_given_text_property_error_events_keep_trimmed_text(
        severity in prop_oneof![Just("warning"), Just("error")],
        message in any_given_text(),
    ) {
        let agent_events =
            read_gemini(&[error_event_line(severity, &message)]);

        let error = expect_first_given(&[&message], UNKNOWN_AGENT_ERROR);
        prop_assert_eq!(agent_events, vec![AgentEvent::ToolFailed(error)]);
    }

    #[test]
    fn test_choose_given_text_property_chosen_text_is_never_blank(
        status in any_status(),
        first_text in any_given_text(),
        second_text in any_given_text(),
    ) {
        let lines = vec![
            tool_result_line(
                ERROR_STATUS,
                Some(&second_text),
                Some(&first_text),
            ),
            error_event_line("error", &first_text),
            result_line(&status, Some((&second_text, &first_text))),
        ];

        let agent_events = read_gemini(&lines);

        for agent_event in &agent_events {
            let (AgentEvent::ToolFailed(text) | AgentEvent::Failed(text)) =
                agent_event
            else {
                continue;
            };
            prop_assert!(!text.trim().is_empty());
            prop_assert_eq!(text.trim(), text.as_str());
        }
    }

    #[test]
    fn test_choose_given_text_property_earlier_text_wins(
        first_text in "[a-z]{1,10}",
        second_text in "[A-Z]{1,10}",
    ) {
        let line =
            result_line(ERROR_STATUS, Some((&second_text, &first_text)));

        let agent_events = read_gemini(&[line]);

        prop_assert_eq!(agent_events, vec![AgentEvent::Failed(first_text)]);
    }
}
