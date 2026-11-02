use std::future::{pending, ready};

use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::RunId;
use orchestration_core::workflow::AgentKind;
use orchestration_runner::output_relay::{RelayEnding, relay_agent_output};
use proptest::collection::vec;
use proptest::prelude::*;
use tokio::runtime::Runtime;
use tokio::sync::mpsc::unbounded_channel;
use uuid::Uuid;

use crate::event_queries::log_texts;
use crate::fake_agent_lines::{
    FakeAgentLine, any_fake_agent_line, reads_as_json, render_line,
};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, to_case_error};

type PostedEvent = (&'static str, String);

const STEP_NAME: &str = "claude-code";
const RUN_NUMBER: u128 = 0x5151;

fn describe_expected_events(lines: &[FakeAgentLine]) -> Vec<PostedEvent> {
    let mut expected = Vec::new();
    for line in lines {
        match line {
            FakeAgentLine::Said(text) => {
                expected.push(("log", format!("Said: {text}")));
                expected.push(("chat", text.clone()));
            }
            FakeAgentLine::UsedBash(command) => {
                let description = format!("Ran {command}");
                expected.push(("log", description.clone()));
                expected.push(("chat", description));
            }
            FakeAgentLine::ToolError(error) => {
                expected.push(("error", error.clone()));
            }
            FakeAgentLine::Session(session) => {
                let started = format!("Agent started, session {session}");
                expected.push(("log", started));
                expected.push(("session", session.clone()));
            }
            FakeAgentLine::Finished => {
                expected.push(("log", "Finished".to_string()));
            }
            FakeAgentLine::Plain(text) if !text.trim().is_empty() => {
                expected.push(("log", text.trim_end().to_string()));
                expected.push(("chat", text.trim_end().to_string()));
            }
            FakeAgentLine::Plain(_) => {}
        }
    }
    expected
}

fn describe_posted_events(events: &[RunEvent]) -> Vec<PostedEvent> {
    let mut posted = Vec::new();
    for event in events {
        match event {
            RunEvent::LogAppended { line } if line.is_error => {
                posted.push(("error", line.text.clone()));
            }
            RunEvent::LogAppended { line } => {
                posted.push(("log", line.text.clone()));
            }
            RunEvent::ChatAppended { message } => {
                posted.push(("chat", message.text.clone()));
            }
            RunEvent::SessionStarted { session } => {
                posted.push(("session", session.clone()));
            }
            _ => posted.push(("other", String::new())),
        }
    }
    posted
}

fn find_last_said(lines: &[FakeAgentLine]) -> Option<String> {
    let mut last_said = None;
    for line in lines {
        match line {
            FakeAgentLine::Said(text) => last_said = Some(text.clone()),
            FakeAgentLine::Plain(text) if !text.trim().is_empty() => {
                last_said = Some(text.trim_end().to_string());
            }
            _ => {}
        }
    }
    last_said
}

fn find_last_session(lines: &[FakeAgentLine]) -> Option<String> {
    let mut last_session = None;
    for line in lines {
        if let FakeAgentLine::Session(session) = line {
            last_session = Some(session.clone());
        }
    }
    last_session
}

fn any_output_line() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>(),
        any_fake_agent_line().prop_map(|line| render_line(&line)),
    ]
}

fn relay_lines(lines: &[String]) -> TestResult<(RelayEnding, Vec<RunEvent>)> {
    let runtime = Runtime::new()?;
    let server = FakeServer::with_queue(Vec::new());
    let run_id = RunId(Uuid::from_u128(RUN_NUMBER));
    let (sender, mut receiver) = unbounded_channel();
    for line in lines {
        sender.send(line.clone())?;
    }
    drop(sender);

    let ending = runtime.block_on(relay_agent_output(
        &server,
        run_id,
        STEP_NAME,
        AgentKind::ClaudeCode,
        &mut receiver,
        pending(),
    ))?;
    Ok((ending, server.events_of(run_id)))
}

#[tokio::test]
async fn stops_relaying_as_soon_as_the_run_is_cancelled() -> TestResult<()> {
    let server = FakeServer::with_queue(Vec::new());
    let run_id = RunId(Uuid::from_u128(RUN_NUMBER));
    let (sender, mut receiver) = unbounded_channel();
    sender.send("still working".to_string())?;

    let ending = relay_agent_output(
        &server,
        run_id,
        STEP_NAME,
        AgentKind::ClaudeCode,
        &mut receiver,
        ready(()),
    )
    .await?;

    assert_eq!(ending, RelayEnding::Cancelled);
    let no_events: Vec<RunEvent> = Vec::new();
    assert_eq!(server.events_of(run_id), no_events);
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(64))]

    #[test]
    fn test_relay_agent_output_property_logs_readable_lines_in_order(
        fake_lines in vec(any_fake_agent_line(), 0..12),
    ) {
        let lines: Vec<String> = fake_lines.iter().map(render_line).collect();

        let (ending, events) = relay_lines(&lines).map_err(to_case_error)?;

        prop_assert_eq!(
            describe_posted_events(&events),
            describe_expected_events(&fake_lines)
        );
        let RelayEnding::OutputEnded(transcript) = ending else {
            return Err(TestCaseError::fail("the relay was cancelled"));
        };
        prop_assert_eq!(transcript.final_message, find_last_said(&fake_lines));
        prop_assert_eq!(transcript.session, find_last_session(&fake_lines));
    }

    #[test]
    fn test_relay_agent_output_property_never_logs_raw_json(
        lines in vec(any_output_line(), 0..8),
    ) {
        let (ending, events) = relay_lines(&lines).map_err(to_case_error)?;

        prop_assert!(matches!(ending, RelayEnding::OutputEnded(_)));
        for log_text in log_texts(&events) {
            prop_assert!(!reads_as_json(&log_text));
            prop_assert!(!log_text.trim().is_empty());
        }
    }
}
