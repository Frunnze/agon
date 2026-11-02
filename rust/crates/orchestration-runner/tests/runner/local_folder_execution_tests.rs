use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::approval::{ApprovalDecision, ApprovalPolicy};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{LocalFolder, render_local_address};
use orchestration_core::task::Task;
use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_hub::clone_source::CloneSource;
use orchestration_runner::run_executor::RunOutcome;
use orchestration_runner::runner_configuration::RunnerConfiguration;
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, claude_task};
use crate::event_queries::{branches, failures};
use crate::executor_support::{
    RUN_NUMBER, execute_with_git_pusher, server_answering,
};
use crate::fake_agent::{
    AgentFolders, has_agent_records, local_configuration,
    prepare_agent_folders,
};
use crate::fake_server::FakeServer;
use crate::git_support::{branch_subjects, run_git};
use crate::support::{TestResult, to_case_error};

const RUNNER_DEVICE: &str = "3f2a9c";
const OTHER_DEVICE: &str = "77b1e0";
const FOLDER_NAME: &str = "billing";
const CHECKED_OUT_BRANCH: &str = "main";
const FIRST_COMMIT: &str = "Start";
const COMMITTING_TITLE: &str = "add-feature\nplease-commit";
const AGENT_COMMIT: &str = "Change by add-feature";

struct FolderScenario {
    folders: AgentFolders,
    folder: PathBuf,
    assignment: RunAssignment,
    configuration: RunnerConfiguration,
}

struct FolderState {
    checked_out_branch: String,
    checked_out_subjects: Vec<String>,
    status: String,
}

fn create_local_folder(root: &Path) -> TestResult<PathBuf> {
    let folder = root.join(FOLDER_NAME);
    fs::create_dir_all(&folder)?;
    run_git(&folder, &["init", "--quiet", "--initial-branch=main"])?;
    fs::write(folder.join("README.md"), "hello")?;
    run_git(&folder, &["add", "--all"])?;
    run_git(&folder, &["commit", "--quiet", "--message", FIRST_COMMIT])?;
    Ok(folder)
}

fn prepare_folder_scenario(
    folder_device: &str,
    approval_policy: ApprovalPolicy,
) -> TestResult<FolderScenario> {
    let folders = prepare_agent_folders()?;
    let folder = create_local_folder(folders.temporary.path())?;
    let local_folder = LocalFolder {
        device_id: DeviceId(folder_device.to_owned()),
        path: folder.display().to_string(),
    };
    let repository = Repository {
        address: render_local_address(&local_folder)?,
        default_branch: CHECKED_OUT_BRANCH.to_owned(),
        agent_access: AgentAccess::PushAfterApproval,
    };
    let task = Task {
        approval_policy,
        ..claude_task(RUN_NUMBER, COMMITTING_TITLE)
    };
    let assignment = assignment_for(task, None, vec![repository], RUN_NUMBER)?;
    let runner_device = DeviceId(RUNNER_DEVICE.to_owned());
    let configuration = RunnerConfiguration {
        clone_source: CloneSource::standard().on_device(runner_device),
        ..local_configuration(&folders, 1)?
    };
    Ok(FolderScenario {
        folders,
        folder,
        assignment,
        configuration,
    })
}

fn read_folder_state(folder: &Path) -> TestResult<FolderState> {
    Ok(FolderState {
        checked_out_branch: run_git(
            folder,
            &["rev-parse", "--abbrev-ref", "HEAD"],
        )?,
        checked_out_subjects: branch_subjects(folder, CHECKED_OUT_BRANCH)?,
        status: run_git(folder, &["status", "--porcelain"])?,
    })
}

#[tokio::test(flavor = "multi_thread")]
async fn pushes_the_task_branch_back_into_the_folder() -> TestResult<()> {
    let policy = ApprovalPolicy::AskBeforeRiskyActions;
    let scenario = prepare_folder_scenario(RUNNER_DEVICE, policy)?;
    let run_id = scenario.assignment.run.id;
    let server = server_answering(ApprovalDecision::Approved);

    let outcome = execute_with_git_pusher(
        &server,
        &scenario.configuration,
        scenario.assignment.clone(),
    )
    .await?;

    let events = server.events_of(run_id);
    let branch = branches(&events).pop().ok_or("no worktree branch")?;
    let state = read_folder_state(&scenario.folder)?;
    assert_eq!(outcome, RunOutcome::Finished);
    assert!(
        branch_subjects(&scenario.folder, &branch)?
            .contains(&AGENT_COMMIT.to_owned())
    );
    assert_eq!(state.checked_out_branch, CHECKED_OUT_BRANCH);
    assert_eq!(state.checked_out_subjects, vec![FIRST_COMMIT.to_owned()]);
    assert_eq!(state.status, "");
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn refuses_a_folder_of_another_computer() -> TestResult<()> {
    let policy = ApprovalPolicy::NeverAsk;
    let scenario = prepare_folder_scenario(OTHER_DEVICE, policy)?;
    let run_id = scenario.assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));

    let outcome = execute_with_git_pusher(
        &server,
        &scenario.configuration,
        scenario.assignment.clone(),
    )
    .await?;

    let events = server.events_of(run_id);
    let reported_failures = failures(&events);
    let failure = reported_failures.first().ok_or("no failure")?;
    assert_eq!(outcome, RunOutcome::Failed);
    assert!(failure.reason.contains("is on another computer"));
    assert_eq!(branches(&events), Vec::<String>::new());
    assert!(!has_agent_records(&scenario.folders)?);
    assert!(!scenario.folders.cache_root.exists());
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

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_execute_property_folder_checkout_is_never_touched(
        approval_policy in any_policy(),
        decision in any_decision(),
    ) {
        let scenario =
            prepare_folder_scenario(RUNNER_DEVICE, approval_policy)
                .map_err(to_case_error)?;
        let run_id = scenario.assignment.run.id;
        let server = server_answering(decision);
        let runtime = Runtime::new().map_err(to_case_error)?;

        let outcome = runtime
            .block_on(execute_with_git_pusher(
                &server,
                &scenario.configuration,
                scenario.assignment.clone(),
            ))
            .map_err(to_case_error)?;

        let events = server.events_of(run_id);
        let branch = branches(&events).pop().ok_or_else(|| {
            TestCaseError::fail("no worktree branch")
        })?;
        let state =
            read_folder_state(&scenario.folder).map_err(to_case_error)?;
        let pushed_subjects = branch_subjects(&scenario.folder, &branch);
        let is_pushed = approval_policy == ApprovalPolicy::NeverAsk
            || decision == ApprovalDecision::Approved;
        prop_assert_eq!(outcome, RunOutcome::Finished);
        prop_assert_eq!(pushed_subjects.is_ok(), is_pushed);
        prop_assert_eq!(state.checked_out_branch, CHECKED_OUT_BRANCH);
        prop_assert_eq!(
            state.checked_out_subjects,
            vec![FIRST_COMMIT.to_owned()]
        );
        prop_assert!(state.status.is_empty());
    }
}
