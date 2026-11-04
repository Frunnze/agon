use std::future::ready;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use orchestration_api::work::{
    CreateApprovalRequest, RunAssignment, RunEvent,
};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalPolicy,
};
use orchestration_core::run::StepStatus;
use orchestration_core::task::Task;
use orchestration_core::workspace::AgentAccess;
use orchestration_runner::agent_run_executor::AgentRunExecutor;
use orchestration_runner::branch_pusher::BranchPusher;
use orchestration_runner::git_command::GitError;
use orchestration_runner::run_executor::{RunExecutor, RunOutcome};
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, claude_task};
use crate::event_queries::{branches, chat_texts, has_status, step_statuses};
use crate::executor_support::{
    RUN_NUMBER, STEP_NAME, execute_with_git_pusher, server_answering,
    step_status_pairs,
};
use crate::fake_agent::{
    AgentFolders, local_configuration, prepare_agent_folders,
};
use crate::fake_server::{ApprovalAnswer, CancellationRule, FakeServer};
use crate::git_support::{branch_subjects, create_bare_origin, repository_at};
use crate::support::{TestResult, hold, to_case_error};

const COMMITTING_TITLE: &str = "add-feature\nplease-commit";
const IDLE_TITLE: &str = "look-around";
const AGENT_COMMIT: &str = "Change by add-feature";

#[derive(Clone, Debug, Default)]
struct RecordingPusher {
    pushed_branches: Arc<Mutex<Vec<String>>>,
}

impl BranchPusher for RecordingPusher {
    fn push_branch(
        &self,
        _worktree: &Path,
        branch: &str,
    ) -> impl Future<Output = Result<(), GitError>> + Send {
        hold(&self.pushed_branches).push(branch.to_string());
        ready(Ok(()))
    }
}

struct PushScenario {
    folders: AgentFolders,
    origin: PathBuf,
    assignment: RunAssignment,
}

fn prepare_push_scenario(
    title: &str,
    approval_policy: ApprovalPolicy,
    agent_access: AgentAccess,
) -> TestResult<PushScenario> {
    let folders = prepare_agent_folders()?;
    let origin = create_bare_origin(folders.temporary.path(), "app", &[])?;
    let repository = repository_at(&origin, agent_access);
    let task = Task {
        approval_policy: Some(approval_policy),
        ..claude_task(RUN_NUMBER, title)
    };
    let assignment = assignment_for(task, None, vec![repository], RUN_NUMBER)?;
    Ok(PushScenario {
        folders,
        origin,
        assignment,
    })
}

async fn execute_with_recording_pusher(
    scenario: &PushScenario,
    server: &Arc<FakeServer>,
    pusher: &RecordingPusher,
) -> TestResult<RunOutcome> {
    let configuration = local_configuration(&scenario.folders, 1)?;
    let executor = AgentRunExecutor::new(
        Arc::clone(server),
        pusher.clone(),
        &configuration,
    )?;
    Ok(executor.execute(scenario.assignment.clone()).await)
}

#[tokio::test(flavor = "multi_thread")]
async fn pushes_approved_commits_to_the_origin() -> TestResult<()> {
    let policy = ApprovalPolicy::AskBeforeRiskyActions;
    let access = AgentAccess::PushAfterApproval;
    let scenario = prepare_push_scenario(COMMITTING_TITLE, policy, access)?;
    let configuration = local_configuration(&scenario.folders, 1)?;
    let run_id = scenario.assignment.run.id;
    let server = server_answering(ApprovalDecision::Approved);

    let outcome = execute_with_git_pusher(
        &server,
        &configuration,
        scenario.assignment.clone(),
    )
    .await?;

    let events = server.events_of(run_id);
    let branch = branches(&events).pop().ok_or("no worktree branch")?;
    let project = scenario.assignment.project.as_ref().ok_or("no project")?;
    let expected_request = CreateApprovalRequest {
        run_id: Some(run_id),
        action: ApprovalAction::PushCommits {
            repository: project.repositories[0].address.clone(),
            branch: branch.clone(),
            commits: vec![AGENT_COMMIT.to_string()],
        },
    };
    let expected_statuses = step_status_pairs(&[
        StepStatus::Running,
        StepStatus::WaitingForApproval,
        StepStatus::Done,
    ]);
    assert_eq!(outcome, RunOutcome::Finished);
    assert_eq!(server.approval_requests(), vec![expected_request]);
    assert!(
        branch_subjects(&scenario.origin, &branch)?
            .contains(&AGENT_COMMIT.to_string())
    );
    assert_eq!(step_statuses(&events), expected_statuses);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn keeps_denied_commits_local_and_says_so() -> TestResult<()> {
    let policy = ApprovalPolicy::AskBeforeRiskyActions;
    let access = AgentAccess::PushAfterApproval;
    let scenario = prepare_push_scenario(COMMITTING_TITLE, policy, access)?;
    let run_id = scenario.assignment.run.id;
    let server = server_answering(ApprovalDecision::Denied);
    let pusher = RecordingPusher::default();

    let outcome =
        execute_with_recording_pusher(&scenario, &server, &pusher).await?;

    let events = server.events_of(run_id);
    let branch = branches(&events).pop().ok_or("no worktree branch")?;
    let project = scenario.assignment.project.as_ref().ok_or("no project")?;
    let expected_note = format!(
        "The push to {branch} in {} was denied, so nothing was pushed.",
        project.repositories[0].address
    );
    assert_eq!(outcome, RunOutcome::Finished);
    assert!(hold(&pusher.pushed_branches).is_empty());
    assert!(chat_texts(&events).contains(&expected_note));
    assert!(has_status(&events, StepStatus::Done));
    assert!(!events.contains(&RunEvent::Finished));
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn pushes_nothing_when_cancelled_during_the_approval() -> TestResult<()>
{
    let policy = ApprovalPolicy::AskBeforeRiskyActions;
    let access = AgentAccess::PushAfterApproval;
    let scenario = prepare_push_scenario(COMMITTING_TITLE, policy, access)?;
    let run_id = scenario.assignment.run.id;
    let server = Arc::new(
        FakeServer::with_queue(Vec::new())
            .answering_approvals(ApprovalAnswer::NeverDecide)
            .cancelling(CancellationRule::WhenApprovalRequested),
    );
    let pusher = RecordingPusher::default();

    let outcome =
        execute_with_recording_pusher(&scenario, &server, &pusher).await?;

    let events = server.events_of(run_id);
    let waiting = (STEP_NAME.to_string(), StepStatus::WaitingForApproval);
    assert_eq!(outcome, RunOutcome::Cancelled);
    assert!(hold(&pusher.pushed_branches).is_empty());
    assert_eq!(step_statuses(&events).last(), Some(&waiting));
    assert!(!events.contains(&RunEvent::Finished));
    Ok(())
}

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn any_decision() -> impl Strategy<Value = ApprovalDecision> {
    prop_oneof![
        Just(ApprovalDecision::Approved),
        Just(ApprovalDecision::Denied),
    ]
}

fn any_access() -> impl Strategy<Value = AgentAccess> {
    prop_oneof![
        Just(AgentAccess::PushAfterApproval),
        Just(AgentAccess::ReadOnly),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(10))]

    #[test]
    fn test_execute_property_pushes_exactly_when_policy_and_decision_allow(
        approval_policy in any_policy(),
        decision in any_decision(),
        agent_access in any_access(),
        makes_commit in any::<bool>(),
    ) {
        let title = if makes_commit { COMMITTING_TITLE } else { IDLE_TITLE };
        let scenario =
            prepare_push_scenario(title, approval_policy, agent_access)
                .map_err(to_case_error)?;
        let server = server_answering(decision);
        let pusher = RecordingPusher::default();
        let runtime = Runtime::new().map_err(to_case_error)?;

        let outcome = runtime
            .block_on(execute_with_recording_pusher(
                &scenario, &server, &pusher,
            ))
            .map_err(to_case_error)?;

        let may_push =
            makes_commit && agent_access == AgentAccess::PushAfterApproval;
        let must_ask = may_push
            && approval_policy == ApprovalPolicy::AskBeforeRiskyActions;
        let is_pushed = may_push
            && (!must_ask || decision == ApprovalDecision::Approved);
        prop_assert_eq!(outcome, RunOutcome::Finished);
        let approval_request_count = server.approval_requests().len();
        prop_assert_eq!(approval_request_count, usize::from(must_ask));
        prop_assert_eq!(
            hold(&pusher.pushed_branches).len(),
            usize::from(is_pushed)
        );
    }
}
