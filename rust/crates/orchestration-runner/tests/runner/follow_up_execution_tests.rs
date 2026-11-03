use std::sync::Arc;

use orchestration_api::work::{FollowUp, RunAssignment};
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_core::run::StepStatus;
use orchestration_core::workspace::AgentAccess;
use orchestration_runner::run_executor::RunOutcome;

use crate::assignments::{assignment_for, claude_assignment, claude_task};
use crate::event_queries::{
    branches, chat_texts, sessions, step_results, step_statuses,
};
use crate::executor_support::{
    RUN_NUMBER, STEP_NAME, execute_with_git_pusher, server_answering,
    step_status_pairs,
};
use crate::fake_agent::{
    local_configuration, prepare_agent_folders, read_calls,
};
use crate::fake_server::FakeServer;
use crate::git_support::{branch_subjects, create_bare_origin, repository_at};
use crate::support::TestResult;

const FIRST_TITLE: &str = "fix-it";
const FIRST_SESSION: &str = "session-fix-it";
const ANSWERED_QUESTION: &str = "old-question";
const NEW_QUESTION: &str = "add-tests";
const IDLE_TITLE: &str = "look-around";
const IDLE_SESSION: &str = "session-look-around";
const EDITING_QUESTION: &str = "please-edit";
const RUNNER_COMMIT: &str = "claude-code: changes from Claude Code";
const ORIGIN_START_COMMIT: &str = "Start";

fn follow_up_of(
    assignment: RunAssignment,
    session: Option<&str>,
    answered_user_messages: usize,
) -> RunAssignment {
    let mut follow_up = assignment;
    follow_up.run.agent_session = session.map(ToString::to_string);
    follow_up.follow_up = Some(FollowUp {
        answered_user_messages,
    });
    follow_up
}

fn server_with_messages(messages: &[&str]) -> Arc<FakeServer> {
    Arc::new(FakeServer::with_queue(Vec::new()).with_user_messages(messages))
}

#[tokio::test(flavor = "multi_thread")]
async fn resumes_the_session_with_only_the_new_message() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let assignment = claude_assignment(RUN_NUMBER, FIRST_TITLE)?;
    let follow_up = follow_up_of(assignment, Some(FIRST_SESSION), 1);
    let run_id = follow_up.run.id;
    let server = server_with_messages(&[ANSWERED_QUESTION, NEW_QUESTION]);

    let outcome =
        execute_with_git_pusher(&server, &configuration, follow_up).await?;

    let events = server.events_of(run_id);
    let expected_calls = vec![format!("{NEW_QUESTION} {FIRST_SESSION}")];
    let expected_statuses =
        step_status_pairs(&[StepStatus::Running, StepStatus::Done]);
    let reply = format!("finished {NEW_QUESTION}");
    let expected_results = vec![(STEP_NAME.to_string(), reply.clone())];
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(read_calls(&folders)?, expected_calls);
    assert_eq!(step_statuses(&events), expected_statuses);
    assert_eq!(chat_texts(&events), vec![reply]);
    assert_eq!(step_results(&events), expected_results);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn runs_the_step_first_when_no_session_was_kept() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let assignment = claude_assignment(RUN_NUMBER, FIRST_TITLE)?;
    let follow_up = follow_up_of(assignment, None, 0);
    let run_id = follow_up.run.id;
    let server = server_with_messages(&[NEW_QUESTION]);

    let outcome =
        execute_with_git_pusher(&server, &configuration, follow_up).await?;

    let expected_calls = vec![
        format!("{FIRST_TITLE} none"),
        format!("{NEW_QUESTION} {FIRST_SESSION}"),
    ];
    let expected_sessions =
        vec![FIRST_SESSION.to_string(), format!("session-{NEW_QUESTION}")];
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(read_calls(&folders)?, expected_calls);
    assert_eq!(sessions(&server.events_of(run_id)), expected_sessions);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn commits_and_asks_to_push_the_follow_up_changes() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let origin = create_bare_origin(folders.temporary.path(), "app", &[])?;
    let repository = repository_at(&origin, AgentAccess::PushAfterApproval);
    let task = claude_task(RUN_NUMBER, IDLE_TITLE);
    let assignment = assignment_for(task, None, vec![repository], RUN_NUMBER)?;
    let first_server = server_answering(ApprovalDecision::Approved);
    let first_outcome = execute_with_git_pusher(
        &first_server,
        &configuration,
        assignment.clone(),
    )
    .await?;
    let follow_up = follow_up_of(assignment, Some(IDLE_SESSION), 0);
    let run_id = follow_up.run.id;
    let server = server_with_messages(&[EDITING_QUESTION]);

    let outcome =
        execute_with_git_pusher(&server, &configuration, follow_up).await?;

    let events = server.events_of(run_id);
    let branch = branches(&events).pop().ok_or("no worktree branch")?;
    let mut requested_commits = Vec::new();
    for request in server.approval_requests() {
        if let ApprovalAction::PushCommits { commits, .. } = request.action {
            requested_commits.push(commits);
        }
    }
    let expected_calls = vec![
        format!("{IDLE_TITLE} none"),
        format!("{EDITING_QUESTION} {IDLE_SESSION}"),
    ];
    let expected_subjects =
        vec![ORIGIN_START_COMMIT.to_string(), RUNNER_COMMIT.to_string()];
    assert_eq!(first_outcome, RunOutcome::Finished);
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(read_calls(&folders)?, expected_calls);
    assert_eq!(requested_commits, vec![vec![RUNNER_COMMIT.to_string()]]);
    assert_eq!(branch_subjects(&origin, &branch)?, expected_subjects);
    Ok(())
}
