use orchestration_core::workflow::AgentKind;
use orchestration_runner::output_relay::RelayEnding;
use proptest::prelude::*;

use crate::event_queries::{chat_texts, log_texts, sessions};
use crate::speech_relay_support::{
    MESSAGE_DELIVERED_NOTE, SAID_PREFIX, any_session, any_speech_parts,
    gemini_finished_line, gemini_init_line, gemini_speech_lines, join_speech,
    relay_until_output_ends, relay_until_stopped_for_messages,
};
use crate::support::to_case_error;

const RELAY_CASES: u32 = 48;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RELAY_CASES))]

    #[test]
    fn test_relay_end_of_output_property_waiting_speech_survives_the_end(
        session in any_session(),
        parts in any_speech_parts(),
    ) {
        let mut lines = vec![gemini_init_line(&session)];
        lines.extend(gemini_speech_lines(&parts));

        let (ending, events) =
            relay_until_output_ends(AgentKind::GeminiCli, &lines)
                .map_err(to_case_error)?;

        let speech = join_speech(&parts);
        let RelayEnding::OutputEnded(transcript) = ending else {
            return Err(TestCaseError::fail("the output did not end"));
        };
        let logged = log_texts(&events);
        prop_assert_eq!(chat_texts(&events), vec![speech.clone()]);
        prop_assert_eq!(
            logged.last(),
            Some(&format!("{SAID_PREFIX}{speech}")),
        );
        prop_assert_eq!(transcript.final_message, Some(speech));
    }

    #[test]
    fn test_relay_end_of_output_property_speech_comes_before_the_delivery(
        session in any_session(),
        parts in any_speech_parts(),
    ) {
        let mut lines = vec![gemini_init_line(&session)];
        lines.extend(gemini_speech_lines(&parts));

        let (ending, events) =
            relay_until_stopped_for_messages(&lines, parts.len())
                .map_err(to_case_error)?;

        let speech = join_speech(&parts);
        let RelayEnding::NewUserMessages(transcript) = ending else {
            return Err(TestCaseError::fail("the agent was not stopped"));
        };
        let expected_chat =
            vec![speech.clone(), MESSAGE_DELIVERED_NOTE.into()];
        prop_assert_eq!(chat_texts(&events), expected_chat);
        prop_assert_eq!(sessions(&events), vec![session.clone()]);
        prop_assert_eq!(transcript.final_message, Some(speech));
        prop_assert_eq!(transcript.session, Some(session));
    }

    #[test]
    fn test_relay_end_of_output_property_said_speech_is_never_repeated(
        parts in any_speech_parts(),
        later_parts in proptest::option::of(any_speech_parts()),
    ) {
        let mut lines = gemini_speech_lines(&parts);
        lines.push(gemini_finished_line());
        let mut expected_chat = vec![join_speech(&parts)];
        if let Some(later_parts) = &later_parts {
            lines.extend(gemini_speech_lines(later_parts));
            expected_chat.push(join_speech(later_parts));
        }

        let (ending, events) =
            relay_until_output_ends(AgentKind::GeminiCli, &lines)
                .map_err(to_case_error)?;

        let RelayEnding::OutputEnded(transcript) = ending else {
            return Err(TestCaseError::fail("the output did not end"));
        };
        let said_logs: Vec<String> = log_texts(&events)
            .into_iter()
            .filter(|text| text.starts_with(SAID_PREFIX))
            .collect();
        prop_assert_eq!(said_logs.len(), expected_chat.len());
        prop_assert_eq!(&chat_texts(&events), &expected_chat);
        prop_assert_eq!(transcript.final_message, expected_chat.pop());
    }
}
