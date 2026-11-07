use orchestration_hub::agent_event::AgentEvent;
use orchestration_hub::agent_log::{AgentLogLine, describe_agent_log_lines};
use proptest::prelude::*;

use crate::agent_reading::parse_agent_line;
use crate::command_support::any_agent;
use crate::json_texts::{join_words, reads_as_json};
use crate::log_support::{
    FAILED_PREFIX, MAXIMUM_LOG_TEXT_CHARACTERS, any_agent_event,
    any_agent_events, any_approval_action, any_event_text, describe_events,
    has_only_kept_controls, is_failure, is_readable,
};

fn describe_one_at_a_time(agent_events: &[AgentEvent]) -> Vec<AgentLogLine> {
    let mut log_lines = Vec::new();
    for agent_event in agent_events {
        log_lines.extend(describe_events(std::slice::from_ref(agent_event)));
    }
    log_lines
}

fn short_readable_text() -> impl Strategy<Value = String> {
    any_event_text().prop_filter("a short readable text", |text| {
        let joined = join_words(text);
        is_readable(text)
            && has_only_kept_controls(text)
            && joined.chars().count() <= MAXIMUM_LOG_TEXT_CHARACTERS
    })
}

fn is_quiet_event(agent_event: &AgentEvent) -> bool {
    !is_failure(agent_event)
}

proptest! {
    #[test]
    fn test_describe_agent_event_property_at_most_one_line_per_event(
        agent_events in any_agent_events(),
        actions in proptest::collection::vec(any_approval_action(), 0..4),
    ) {
        let approvals: Vec<AgentEvent> = actions
            .into_iter()
            .map(AgentEvent::AskedForApproval)
            .collect();

        let log_lines = describe_events(&agent_events);

        prop_assert!(log_lines.len() <= agent_events.len());
        prop_assert_eq!(describe_events(&approvals), Vec::new());
    }

    #[test]
    fn test_describe_agent_event_property_errors_come_only_from_failures(
        agent_events in any_agent_events(),
    ) {
        let log_lines = describe_events(&agent_events);

        let error_count =
            log_lines.iter().filter(|log_line| log_line.is_error).count();
        let failure_count =
            agent_events.iter().filter(|event| is_failure(event)).count();
        prop_assert!(error_count <= failure_count);
    }

    #[test]
    fn test_describe_agent_event_property_events_are_described_in_order(
        agent_events in any_agent_events(),
    ) {
        let log_lines = describe_events(&agent_events);

        prop_assert_eq!(log_lines, describe_one_at_a_time(&agent_events));
    }

    #[test]
    fn test_normal_line_property_printed_lines_are_never_errors(
        agent in any_agent(),
        line in any::<String>(),
    ) {
        prop_assume!(!reads_as_json(&line));

        let log_lines = describe_agent_log_lines(
            &line,
            &parse_agent_line(agent, &line),
        );

        prop_assert!(log_lines.len() <= 1);
        prop_assert!(log_lines.iter().all(|log_line| !log_line.is_error));
    }

    #[test]
    fn test_normal_line_property_quiet_events_give_normal_lines(
        agent_event in any_agent_event(),
    ) {
        prop_assume!(is_quiet_event(&agent_event));

        let log_lines = describe_events(std::slice::from_ref(&agent_event));

        prop_assert!(log_lines.iter().all(|log_line| !log_line.is_error));
    }

    #[test]
    fn test_normal_line_property_printed_text_is_kept_as_printed(
        agent in any_agent(),
        line in "\\PC{1,60}",
    ) {
        prop_assume!(!reads_as_json(&line));

        let log_lines = describe_agent_log_lines(
            &line,
            &parse_agent_line(agent, &line),
        );

        let printed = line.trim_end();
        let mut expected = Vec::new();
        if !printed.trim_start().is_empty() {
            expected.push(AgentLogLine {
                text: printed.to_owned(),
                is_error: false,
            });
        }
        prop_assert_eq!(log_lines, expected);
    }

    #[test]
    fn test_error_line_property_tool_failures_show_without_a_prefix(
        error_text in short_readable_text(),
    ) {
        let log_lines =
            describe_events(&[AgentEvent::ToolFailed(error_text.clone())]);

        let expected = AgentLogLine {
            text: join_words(&error_text),
            is_error: true,
        };
        prop_assert_eq!(log_lines, vec![expected]);
    }

    #[test]
    fn test_error_line_property_failures_carry_the_failed_prefix(
        reason in short_readable_text(),
    ) {
        let log_lines = describe_events(&[AgentEvent::Failed(reason.clone())]);

        let expected = AgentLogLine {
            text: format!("{FAILED_PREFIX}{}", join_words(&reason)),
            is_error: true,
        };
        prop_assert_eq!(log_lines, vec![expected]);
    }

    #[test]
    fn test_error_line_property_each_readable_failure_gives_one_error(
        agent_events in any_agent_events(),
    ) {
        let log_lines = describe_events(&agent_events);

        let error_count =
            log_lines.iter().filter(|log_line| log_line.is_error).count();
        let readable_failures = agent_events
            .iter()
            .filter(|agent_event| match agent_event {
                AgentEvent::ToolFailed(text) | AgentEvent::Failed(text) => {
                    is_readable(text)
                }
                _ => false,
            })
            .count();
        prop_assert_eq!(error_count, readable_failures);
    }
}
