use std::fs;
use std::path::Path;

use orchestration_api::work::RunAssignment;
use orchestration_core::run::StepStatus;
use orchestration_core::task::{Task, TaskPlace};
use orchestration_core::workspace::AgentAccess;

use crate::event_queries::{branches, step_statuses};
use crate::fake_agent::prepare_agent_folders;
use crate::fan_out_runs::{
    FanOutRun, queue_reviewers, run_fan_out, statuses_of_step,
};
use crate::git_support::{
    branch_subjects, create_bare_origin, repository_at, run_git,
};
use crate::support::TestResult;

const GATHER_BOTH: &str = "please-gather-2";
const LINGER: &str = "please-linger";
const WRITE_OWN_FILE: &str = "please-write-own-file";
const REPOSITORY_NAME: &str = "app";
const ORIGIN_START_COMMIT: &str = "Start";
const COMBINED_COMMIT: &str = "step-1: changes from Claude Code; \
    step-2: changes from Claude Code";
const OWN_FILES: [&str; 2] = ["step-1.md", "step-2.md"];
const LINGERING_FILE: &str = "step-2.md";
const LINGERING_FILE_TEXT: &str =
    "first half by step-2\nsecond half by step-2";

fn without_project(assignment: RunAssignment) -> RunAssignment {
    let workspace_id = assignment.workspace_id;
    let task = Task {
        place: TaskPlace::InWorkspace { workspace_id },
        ..assignment.task
    };
    RunAssignment {
        project: None,
        task,
        ..assignment
    }
}

fn assert_every_reviewer_done(fan_out: &FanOutRun) {
    let events = fan_out.server.events_of(fan_out.run_id);
    let statuses = step_statuses(&events);
    for reviewer_name in &fan_out.reviewer_names {
        assert_eq!(
            statuses_of_step(&statuses, reviewer_name),
            vec![StepStatus::Running, StepStatus::Done],
            "{reviewer_name} in {events:?}"
        );
    }
}

fn count_task_folders(worktrees_root: &Path) -> TestResult<usize> {
    if !worktrees_root.exists() {
        return Ok(0);
    }
    Ok(fs::read_dir(worktrees_root)?.count())
}

fn files_in_commit(origin: &Path, reference: &str) -> TestResult<Vec<String>> {
    let arguments = ["show", "--name-only", "--format=", reference];
    let names = run_git(origin, &arguments)?;
    Ok(names.lines().map(ToString::to_string).collect())
}

#[test]
fn a_draft_keeps_its_folder_until_its_last_step_leaves() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let instructions =
        [GATHER_BOTH.to_string(), format!("{GATHER_BOTH}\n{LINGER}")];
    let assignments = queue_reviewers(&instructions, Vec::new())?;
    let drafting_assignments =
        assignments.into_iter().map(without_project).collect();

    let fan_out = run_fan_out(folders, drafting_assignments)?;

    assert_every_reviewer_done(&fan_out);
    let worktrees_root = &fan_out.folders.worktrees_root;
    assert_eq!(count_task_folders(worktrees_root)?, 0);
    Ok(())
}

#[test]
fn parallel_steps_commit_their_finished_files_together() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let root = folders.temporary.path();
    let origin = create_bare_origin(root, REPOSITORY_NAME, &[])?;
    let repository = repository_at(&origin, AgentAccess::PushAfterApproval);
    let instructions = [
        format!("{GATHER_BOTH}\n{WRITE_OWN_FILE}"),
        format!("{GATHER_BOTH}\n{WRITE_OWN_FILE}\n{LINGER}"),
    ];
    let assignments = queue_reviewers(&instructions, vec![repository])?;

    let fan_out = run_fan_out(folders, assignments)?;

    assert_every_reviewer_done(&fan_out);
    let events = fan_out.server.events_of(fan_out.run_id);
    let branch = branches(&events).pop().ok_or("no worktree branch")?;
    let reference = format!("refs/heads/{branch}");
    let lingering_file = format!("{reference}:{LINGERING_FILE}");
    assert_eq!(
        branch_subjects(&origin, &branch)?,
        vec![ORIGIN_START_COMMIT.to_string(), COMBINED_COMMIT.to_string()]
    );
    assert_eq!(files_in_commit(&origin, &reference)?, OWN_FILES.to_vec());
    assert_eq!(
        run_git(&origin, &["show", &lingering_file])?,
        LINGERING_FILE_TEXT
    );
    Ok(())
}
