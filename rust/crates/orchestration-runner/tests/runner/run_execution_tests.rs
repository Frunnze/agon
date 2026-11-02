use std::sync::Arc;
use std::time::{Duration, Instant};

use orchestration_api::work::RunEvent;
use orchestration_core::run::{ChatAuthor, RunFailure, StepStatus};
use orchestration_runner::run_executor::RunOutcome;

use crate::assignments::claude_assignment;
use crate::event_queries::{
    chat_messages, chat_texts, failures, has_status, log_texts, sessions,
    step_results, step_statuses,
};
use crate::executor_support::{
    RUN_NUMBER, STEP_NAME, execute_with_git_pusher, step_status_pairs,
};
use crate::fake_agent::{
    local_configuration, prepare_agent_folders, read_calls, read_prompt,
};
use crate::fake_server::{CancellationRule, FakeServer};
use crate::support::TestResult;

const REPLAYED_SESSION: &str = "5f0c3e2a-9b1d-4c7e-8a6f-2d4b1e9c7a30";
const CANCELLATION_LIMIT: Duration = Duration::from_secs(10);
const DRAFTED_WORKFLOW: &str = "{\"name\":\"release\",\"agents\":[\
    {\"name\":\"plan\",\"task\":\"Plan the release\"},\
    {\"name\":\"build\",\"task\":\"Build the app\"}],\
    \"connections\":[{\"from\":\"plan\",\"to\":\"build\"}]}";

fn no_step_results() -> Vec<(String, String)> {
    Vec::new()
}

#[tokio::test(flavor = "multi_thread")]
async fn replays_a_claude_session_into_run_events() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let assignment = claude_assignment(RUN_NUMBER, "fix-build please-replay")?;
    let run_id = assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));

    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let events = server.events_of(run_id);
    let expected_log = vec![
        format!("Agent started, session {REPLAYED_SESSION}"),
        "Said: I'll build the app first to see the error.".to_string(),
        "Ran xcodebuild -scheme App".to_string(),
        "** BUILD FAILED ** error: Signing for \"App\" requires a \
         development team."
            .to_string(),
        "Edited ios/App.xcodeproj/project.pbxproj".to_string(),
        "Said: The signing team is set and the build passes now.".to_string(),
        "Finished".to_string(),
    ];
    let expected_chat = vec![
        "I'll build the app first to see the error.",
        "Ran xcodebuild -scheme App",
        "Edited ios/App.xcodeproj/project.pbxproj",
        "The signing team is set and the build passes now.",
    ];
    let authors: Vec<ChatAuthor> = chat_messages(&events)
        .iter()
        .map(|message| message.author)
        .collect();
    let expected_authors = vec![
        ChatAuthor::Agent,
        ChatAuthor::Tool,
        ChatAuthor::Tool,
        ChatAuthor::Agent,
    ];
    let expected_statuses =
        step_status_pairs(&[StepStatus::Running, StepStatus::Done]);
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(log_texts(&events), expected_log);
    assert_eq!(chat_texts(&events), expected_chat);
    assert_eq!(authors, expected_authors);
    assert_eq!(sessions(&events), vec![REPLAYED_SESSION.to_string()]);
    assert_eq!(step_statuses(&events), expected_statuses);
    assert!(matches!(
        events.first(),
        Some(RunEvent::WorktreeCreated { .. })
    ));
    let last_message = expected_chat[3].to_string();
    let recorded = vec![(STEP_NAME.to_string(), last_message.clone())];
    assert_eq!(step_results(&events), recorded);
    let finishing = &events[events.len() - 2..];
    let expected_finishing = [
        RunEvent::StepResultRecorded {
            step_name: STEP_NAME.to_string(),
            result: last_message,
        },
        RunEvent::StepStatusChanged {
            step_name: STEP_NAME.to_string(),
            status: StepStatus::Done,
        },
    ];
    assert_eq!(finishing, expected_finishing);
    assert!(!events.contains(&RunEvent::Finished));
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn fails_the_run_when_the_agent_exits_with_an_error() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let assignment = claude_assignment(RUN_NUMBER, "broken please-fail")?;
    let run_id = assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));

    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let events = server.events_of(run_id);
    let expected_failure = RunFailure {
        step_name: STEP_NAME.to_string(),
        runner: None,
        reason: "the agent exited with code 3".to_string(),
        retry_runs_on_same_runner: true,
    };
    let expected_statuses =
        step_status_pairs(&[StepStatus::Running, StepStatus::Failed]);
    assert_eq!(outcome, RunOutcome::Failed);
    assert_eq!(step_statuses(&events), expected_statuses);
    assert_eq!(failures(&events), vec![expected_failure]);
    assert_eq!(log_texts(&events), vec!["the agent broke".to_string()]);
    assert_eq!(step_results(&events), no_step_results());
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn stops_the_agent_when_the_run_is_cancelled() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let assignment = claude_assignment(RUN_NUMBER, "long-job please-wait")?;
    let run_id = assignment.run.id;
    let rule = CancellationRule::WhenLogContains("started".to_string());
    let server = Arc::new(FakeServer::with_queue(Vec::new()).cancelling(rule));
    let started_at = Instant::now();

    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let events = server.events_of(run_id);
    assert_eq!(outcome, RunOutcome::Cancelled);
    assert!(started_at.elapsed() < CANCELLATION_LIMIT);
    assert!(!has_status(&events, StepStatus::Done));
    assert!(!has_status(&events, StepStatus::Failed));
    let no_failures: Vec<RunFailure> = Vec::new();
    assert_eq!(failures(&events), no_failures);
    assert_eq!(step_results(&events), no_step_results());
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn continues_the_agent_session_with_the_users_message() -> TestResult<()>
{
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let assignment = claude_assignment(RUN_NUMBER, "fix-it")?;
    let run_id = assignment.run.id;
    let messages = ["add-tests", "   "];
    let server = Arc::new(
        FakeServer::with_queue(Vec::new()).with_user_messages(&messages),
    );

    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let events = server.events_of(run_id);
    let expected_calls = vec![
        "fix-it none".to_string(),
        "add-tests session-fix-it".to_string(),
    ];
    let expected_sessions = vec![
        "session-fix-it".to_string(),
        "session-add-tests".to_string(),
    ];
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(read_calls(&folders)?, expected_calls);
    assert_eq!(read_prompt(&folders, "add-tests")?, "add-tests");
    assert_eq!(sessions(&events), expected_sessions);
    assert!(chat_texts(&events).contains(&"finished add-tests".to_string()));
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn passes_a_drafted_workflow_through_unchanged() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let assignment = claude_assignment(RUN_NUMBER, "draft please-draft")?;
    let run_id = assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));

    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let chat = chat_texts(&server.events_of(run_id));
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(chat.last().map(String::as_str), Some(DRAFTED_WORKFLOW));
    Ok(())
}
