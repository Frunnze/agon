use std::fs;
use std::path::PathBuf;
use std::sync::Arc;

use orchestration_core::identifiers::SkillId;
use orchestration_core::library::{Skill, SkillSource, SkillUsage};
use orchestration_core::scope::Scope;
use orchestration_core::task::Task;
use orchestration_runner::run_executor::RunOutcome;
use proptest::prelude::*;
use tokio::runtime::Runtime;
use uuid::Uuid;

use crate::assignments::{claude_task, workspace_assignment_for};
use crate::executor_support::{RUN_NUMBER, execute_with_git_pusher};
use crate::fake_agent::{
    AgentFolders, local_configuration, prepare_agent_folders, read_prompt,
    read_working_folders,
};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, to_case_error};

const WORKSPACE_RUN_CASES: u32 = 6;
const AGENT_INSTRUCTIONS: [&str; 3] =
    ["please-edit", "please-commit", "please-draft"];
const DRAFTING_TITLE: &str = "draft-new-task";
const SKILL_INSTRUCTIONS: &str = "Instructions of style.";

struct WorkspaceRunReport {
    outcome: RunOutcome,
    working_folders: Vec<PathBuf>,
    approval_request_count: usize,
    folders: AgentFolders,
}

fn automatic_skill() -> Skill {
    Skill {
        id: SkillId(Uuid::from_u128(1)),
        name: "style".to_owned(),
        summary: String::new(),
        instructions: SKILL_INSTRUCTIONS.to_owned(),
        scope: Scope::everywhere(),
        usage: SkillUsage::Automatic,
        source: SkillSource::Created,
    }
}

fn run_in_workspace(details: &str) -> TestResult<WorkspaceRunReport> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let task = Task {
        details: details.to_owned(),
        uses_automatic_skills: true,
        ..claude_task(RUN_NUMBER, DRAFTING_TITLE)
    };
    let mut assignment = workspace_assignment_for(task, RUN_NUMBER)?;
    assignment.skills = vec![automatic_skill()];
    let server = Arc::new(FakeServer::with_queue(Vec::new()));
    let runtime = Runtime::new()?;

    let outcome = runtime.block_on(execute_with_git_pusher(
        &server,
        &configuration,
        assignment,
    ))?;

    Ok(WorkspaceRunReport {
        outcome,
        working_folders: read_working_folders(&folders)?,
        approval_request_count: server.approval_requests().len(),
        folders,
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WORKSPACE_RUN_CASES))]

    #[test]
    fn test_execute_property_a_workspace_run_leaves_no_folder_behind(
        instruction in proptest::sample::select(AGENT_INSTRUCTIONS.to_vec()),
    ) {
        let report = run_in_workspace(instruction).map_err(to_case_error)?;

        prop_assert_eq!(report.outcome, RunOutcome::Finished);
        prop_assert_eq!(report.approval_request_count, 0);
        prop_assert_eq!(report.working_folders.len(), 1);
        let working_folder = &report.working_folders[0];
        let worktrees_root = report
            .folders
            .worktrees_root
            .canonicalize()
            .map_err(to_case_error)?;
        prop_assert!(working_folder.starts_with(&worktrees_root));
        prop_assert!(!working_folder.exists());
        let left_folders =
            fs::read_dir(&worktrees_root).map_err(to_case_error)?;
        prop_assert_eq!(left_folders.count(), 0);
        prop_assert!(!report.folders.cache_root.exists());
    }
}

#[test]
fn a_workspace_run_offers_the_agent_no_skills() -> TestResult<()> {
    let report = run_in_workspace("Draft a new task.")?;

    let prompt = read_prompt(&report.folders, DRAFTING_TITLE)?;
    assert_eq!(report.outcome, RunOutcome::Finished);
    assert!(prompt.contains("Draft a new task."), "{prompt}");
    assert!(!prompt.contains(SKILL_INSTRUCTIONS), "{prompt}");
    Ok(())
}
