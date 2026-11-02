use std::path::PathBuf;
use std::sync::Arc;

use orchestration_api::work::{CreateApprovalRequest, RunAssignment};
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_core::run::StepStatus;
use orchestration_core::workspace::AgentAccess;
use orchestration_runner::agents_file::AGENTS_FILE_NAME;
use orchestration_runner::run_executor::RunOutcome;

use crate::assignments::{assignment_for, claude_task, rule_titled};
use crate::event_queries::{branches, failures, step_statuses};
use crate::executor_support::{
    RUN_NUMBER, execute_with_git_pusher, server_answering, step_status_pairs,
};
use crate::fake_agent::{
    AgentFolders, local_configuration, prepare_agent_folders,
};
use crate::fake_server::FakeServer;
use crate::git_support::{
    branch_subjects, create_bare_origin, repository_at, run_git,
};
use crate::leftover_changes::PROJECT_AGENTS_NOTES;
use crate::support::TestResult;

const EDITING_TITLE: &str = "add-feature\nplease-edit";
const COMMITTING_AND_EDITING_TITLE: &str =
    "add-feature\nplease-commit\nplease-edit";
const LOCKING_TITLE: &str = "add-feature\nplease-edit\nplease-lock";
const IDLE_TITLE: &str = "look-around";
const AGENT_COMMIT: &str = "Change by add-feature";
const RUNNER_COMMIT: &str = "claude-code: changes from Claude Code";
const ORIGIN_START_COMMIT: &str = "Start";
const EDITED_FILES: [&str; 2] = ["NOTES.md", "README.md"];
const LOCKED_REASON_START: &str = "could not commit the changes left in \
    local.test/acme/app: git add --all failed";

struct ChangeScenario {
    folders: AgentFolders,
    origin: PathBuf,
    assignment: RunAssignment,
}

fn prepare_change_scenario(
    title: &str,
    project_files: &[(&str, &str)],
) -> TestResult<ChangeScenario> {
    let folders = prepare_agent_folders()?;
    let origin =
        create_bare_origin(folders.temporary.path(), "app", project_files)?;
    let repository = repository_at(&origin, AgentAccess::PushAfterApproval);
    let task = claude_task(RUN_NUMBER, title);
    let mut assignment =
        assignment_for(task, None, vec![repository], RUN_NUMBER)?;
    assignment.rules = vec![rule_titled(1, "Never push to main", true)];
    Ok(ChangeScenario {
        folders,
        origin,
        assignment,
    })
}

async fn run_with_approval(
    scenario: &ChangeScenario,
) -> TestResult<(RunOutcome, Arc<FakeServer>)> {
    let configuration = local_configuration(&scenario.folders, 1)?;
    let server = server_answering(ApprovalDecision::Approved);
    let assignment = scenario.assignment.clone();
    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;
    Ok((outcome, server))
}

fn requested_commits(server: &FakeServer) -> Vec<Vec<String>> {
    let mut commits = Vec::new();
    for request in server.approval_requests() {
        if let ApprovalAction::PushCommits {
            commits: requested, ..
        } = request.action
        {
            commits.push(requested);
        }
    }
    commits
}

fn pushed_branch(
    scenario: &ChangeScenario,
    server: &FakeServer,
) -> TestResult<String> {
    let events = server.events_of(scenario.assignment.run.id);
    Ok(branches(&events).pop().ok_or("no worktree branch")?)
}

fn files_in_pushed_commit(
    scenario: &ChangeScenario,
    server: &FakeServer,
) -> TestResult<Vec<String>> {
    let branch = pushed_branch(scenario, server)?;
    let arguments = ["show", "--name-only", "--format=", branch.as_str()];
    let names = run_git(&scenario.origin, &arguments)?;
    Ok(names.lines().map(ToString::to_string).collect())
}

fn expected_files() -> Vec<String> {
    EDITED_FILES.iter().map(ToString::to_string).collect()
}

#[tokio::test(flavor = "multi_thread")]
async fn commits_what_the_agent_left_and_asks_to_push_it() -> TestResult<()> {
    let scenario = prepare_change_scenario(EDITING_TITLE, &[])?;

    let (outcome, server) = run_with_approval(&scenario).await?;

    let branch = pushed_branch(&scenario, &server)?;
    let expected_subjects =
        vec![ORIGIN_START_COMMIT.to_string(), RUNNER_COMMIT.to_string()];
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(
        requested_commits(&server),
        vec![vec![RUNNER_COMMIT.to_string()]]
    );
    assert_eq!(
        branch_subjects(&scenario.origin, &branch)?,
        expected_subjects
    );
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn adds_no_commit_when_the_agent_left_nothing() -> TestResult<()> {
    let project_notes = [(AGENTS_FILE_NAME, PROJECT_AGENTS_NOTES)];
    let scenario = prepare_change_scenario(IDLE_TITLE, &project_notes)?;

    let (outcome, server) = run_with_approval(&scenario).await?;

    let events = server.events_of(scenario.assignment.run.id);
    let expected_statuses =
        step_status_pairs(&[StepStatus::Running, StepStatus::Done]);
    assert_eq!(outcome, RunOutcome::Finished);
    let no_requests: Vec<CreateApprovalRequest> = Vec::new();
    assert_eq!(server.approval_requests(), no_requests);
    assert_eq!(step_statuses(&events), expected_statuses);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn never_commits_the_runners_agents_file() -> TestResult<()> {
    let scenario = prepare_change_scenario(EDITING_TITLE, &[])?;

    let (outcome, server) = run_with_approval(&scenario).await?;

    let branch = pushed_branch(&scenario, &server)?;
    let listing_arguments = ["ls-tree", "--name-only", branch.as_str()];
    let pushed_tree = run_git(&scenario.origin, &listing_arguments)?;
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(
        files_in_pushed_commit(&scenario, &server)?,
        expected_files()
    );
    assert!(!pushed_tree.lines().any(|name| name == AGENTS_FILE_NAME));
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn keeps_the_projects_own_agents_file_as_it_was() -> TestResult<()> {
    let project_notes = [(AGENTS_FILE_NAME, PROJECT_AGENTS_NOTES)];
    let scenario = prepare_change_scenario(EDITING_TITLE, &project_notes)?;

    let (outcome, server) = run_with_approval(&scenario).await?;

    let branch = pushed_branch(&scenario, &server)?;
    let pushed_path = format!("{branch}:{AGENTS_FILE_NAME}");
    let pushed_notes = run_git(&scenario.origin, &["show", &pushed_path])?;
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(
        files_in_pushed_commit(&scenario, &server)?,
        expected_files()
    );
    assert_eq!(pushed_notes, PROJECT_AGENTS_NOTES);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn keeps_the_agents_commit_and_adds_one_for_the_rest() -> TestResult<()>
{
    let scenario = prepare_change_scenario(COMMITTING_AND_EDITING_TITLE, &[])?;

    let (outcome, server) = run_with_approval(&scenario).await?;

    let expected_commits =
        vec![AGENT_COMMIT.to_string(), RUNNER_COMMIT.to_string()];
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(requested_commits(&server), vec![expected_commits]);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn fails_the_step_when_git_cannot_commit_the_changes() -> TestResult<()>
{
    let scenario = prepare_change_scenario(LOCKING_TITLE, &[])?;

    let (outcome, server) = run_with_approval(&scenario).await?;

    let events = server.events_of(scenario.assignment.run.id);
    let reasons: Vec<String> = failures(&events)
        .into_iter()
        .map(|failure| failure.reason)
        .collect();
    let expected_statuses =
        step_status_pairs(&[StepStatus::Running, StepStatus::Failed]);
    assert_eq!(outcome, RunOutcome::Failed);
    assert_eq!(step_statuses(&events), expected_statuses);
    let no_requests: Vec<CreateApprovalRequest> = Vec::new();
    assert_eq!(server.approval_requests(), no_requests);
    assert_eq!(reasons.len(), 1);
    assert!(reasons[0].starts_with(LOCKED_REASON_START), "{reasons:?}");
    Ok(())
}
