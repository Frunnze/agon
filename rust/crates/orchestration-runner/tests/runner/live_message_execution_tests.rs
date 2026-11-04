use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::AgentKind;
use orchestration_runner::run_executor::RunOutcome;

use crate::assignments::{assignment_for, claude_assignment, task_for};
use crate::event_queries::{chat_texts, step_results};
use crate::executor_support::{RUN_NUMBER, execute_with_git_pusher};
use crate::fake_agent::{
    local_configuration, prepare_agent_folders, read_calls,
};
use crate::fake_server::FakeServer;
use crate::support::TestResult;

const WORKING_TITLE: &str = "long-job\nplease-work";
const QUICK_TITLE: &str = "fix-it";
const STOP_MESSAGE: &str = "lets-stop";
const WORKING_REPLY: &str = "working on long-job";
const TURN_END_LOG: &str = "Finished";
const DELIVERED_NOTE: &str = "Message delivered to the agent";
const STOP_REPLY: &str = "finished lets-stop";
const QUICK_REPLY: &str = "finished fix-it";

struct Conversation {
    outcome: RunOutcome,
    calls: Vec<String>,
    chat: Vec<String>,
    results: Vec<String>,
}

fn codex_assignment(title: &str) -> TestResult<RunAssignment> {
    let doer = TaskDoer::OneAgent {
        agent: AgentKind::Codex,
    };
    let task = task_for(RUN_NUMBER, title, doer);
    assignment_for(task, None, Vec::new(), RUN_NUMBER)
}

async fn send_message_once_logged(
    assignment: RunAssignment,
    log_text: &str,
) -> TestResult<Conversation> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let run_id = assignment.run.id;
    let server = Arc::new(
        FakeServer::with_queue(Vec::new())
            .with_user_messages_once_logged(log_text, &[STOP_MESSAGE]),
    );

    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let events = server.events_of(run_id);
    let mut results = Vec::new();
    for (_step_name, result) in step_results(&events) {
        results.push(result);
    }
    Ok(Conversation {
        outcome,
        calls: read_calls(&folders)?,
        chat: chat_texts(&events),
        results,
    })
}

#[tokio::test(flavor = "multi_thread")]
async fn a_message_interrupts_claude_code_on_its_open_input() -> TestResult<()>
{
    let assignment = claude_assignment(RUN_NUMBER, WORKING_TITLE)?;

    let conversation =
        send_message_once_logged(assignment, WORKING_REPLY).await?;

    let expected_calls = vec!["long-job none", "lets-stop same-process"];
    let expected_chat = vec![WORKING_REPLY, DELIVERED_NOTE, STOP_REPLY];
    assert_eq!(conversation.outcome, RunOutcome::Finished);
    assert_eq!(conversation.calls, expected_calls);
    assert_eq!(conversation.chat, expected_chat);
    assert_eq!(conversation.results, vec![STOP_REPLY]);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn a_message_restarts_codex_in_its_session() -> TestResult<()> {
    let assignment = codex_assignment(WORKING_TITLE)?;

    let conversation =
        send_message_once_logged(assignment, WORKING_REPLY).await?;

    let expected_calls = vec!["long-job none", "lets-stop thread-long-job"];
    let expected_chat = vec![WORKING_REPLY, DELIVERED_NOTE, STOP_REPLY];
    assert_eq!(conversation.outcome, RunOutcome::Finished);
    assert_eq!(conversation.calls, expected_calls);
    assert_eq!(conversation.chat, expected_chat);
    assert_eq!(conversation.results, vec![STOP_REPLY]);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn a_message_after_claude_codes_turn_resumes_its_session()
-> TestResult<()> {
    let assignment = claude_assignment(RUN_NUMBER, QUICK_TITLE)?;

    let conversation =
        send_message_once_logged(assignment, TURN_END_LOG).await?;

    let expected_calls = vec!["fix-it none", "lets-stop session-fix-it"];
    assert_eq!(conversation.outcome, RunOutcome::Finished);
    assert_eq!(conversation.calls, expected_calls);
    assert_eq!(conversation.chat, vec![QUICK_REPLY, STOP_REPLY]);
    assert_eq!(conversation.results, vec![STOP_REPLY]);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn a_message_after_codexs_turn_resumes_its_session() -> TestResult<()> {
    let assignment = codex_assignment(QUICK_TITLE)?;

    let conversation =
        send_message_once_logged(assignment, TURN_END_LOG).await?;

    let expected_calls = vec!["fix-it none", "lets-stop thread-fix-it"];
    assert_eq!(conversation.outcome, RunOutcome::Finished);
    assert_eq!(conversation.calls, expected_calls);
    assert_eq!(conversation.chat, vec![QUICK_REPLY, STOP_REPLY]);
    assert_eq!(conversation.results, vec![STOP_REPLY]);
    Ok(())
}
