use std::collections::BTreeSet;
use std::fs;
use std::ops::Range;
use std::path::{Path, PathBuf};

use orchestration_runner::agents_file::{AGENTS_FILE_NAME, write_agents_file};
use proptest::collection::{btree_set, vec};
use proptest::prelude::*;
use tempfile::TempDir;

use crate::git_support::{clone_working_copy, create_bare_origin, run_git};
use crate::support::TestResult;

pub const PROJECT_AGENTS_NOTES: &str = "# Project\nUse pnpm.";
pub const CREATED_FILE_NAMES: &str = "[a-z]{1,8}\\.new";
pub const CREATED_CONTENT: &str = "created by the agent\n";

const TRACKED_FILES: [&str; 3] = ["first.txt", "second.txt", "third.txt"];
const ORIGINAL_CONTENT: &str = "original\n";
const EDITED_CONTENT: &str = "edited by the agent\n";
const RULES_MARKDOWN: &str = "# Rules\n\n- [a-z ]{1,20}\\.\n";

type LeftoverChangeParts = (
    Vec<TrackedFileChange>,
    BTreeSet<String>,
    String,
    ProjectAgentsFile,
);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ProjectAgentsFile {
    Tracked,
    Absent,
}

#[derive(Clone, Copy, Debug)]
pub enum TrackedFileChange {
    Keep,
    Edit,
    Delete,
}

#[derive(Clone, Debug)]
pub struct LeftoverChanges {
    pub tracked_file_changes: Vec<TrackedFileChange>,
    pub created_files: BTreeSet<String>,
    pub rules_markdown: String,
    pub project_agents_file: ProjectAgentsFile,
}

#[derive(Debug)]
pub struct CheckedOutRepository {
    _folder: TempDir,
    pub worktree: PathBuf,
}

pub fn check_out_repository(
    project_agents_file: ProjectAgentsFile,
) -> TestResult<CheckedOutRepository> {
    let folder = tempfile::tempdir()?;
    let mut files = Vec::new();
    for file_name in TRACKED_FILES {
        files.push((file_name, ORIGINAL_CONTENT));
    }
    if project_agents_file == ProjectAgentsFile::Tracked {
        files.push((AGENTS_FILE_NAME, PROJECT_AGENTS_NOTES));
    }

    let origin = create_bare_origin(folder.path(), "app", &files)?;
    let destination = folder.path().join("work/app");
    let worktree = clone_working_copy(&origin, &destination)?;
    Ok(CheckedOutRepository {
        _folder: folder,
        worktree,
    })
}

pub fn leave_changes(
    worktree: &Path,
    changes: &LeftoverChanges,
) -> TestResult<BTreeSet<String>> {
    let mut changed_files = BTreeSet::new();
    let tracked = TRACKED_FILES.iter().zip(&changes.tracked_file_changes);
    for (file_name, change) in tracked {
        let path = worktree.join(file_name);
        match change {
            TrackedFileChange::Keep => continue,
            TrackedFileChange::Edit => fs::write(&path, EDITED_CONTENT)?,
            TrackedFileChange::Delete => fs::remove_file(&path)?,
        }
        changed_files.insert((*file_name).to_string());
    }

    for file_name in &changes.created_files {
        fs::write(worktree.join(file_name), CREATED_CONTENT)?;
        changed_files.insert(file_name.clone());
    }
    write_agents_file(worktree, &changes.rules_markdown)?;
    Ok(changed_files)
}

pub fn commit_subjects(worktree: &Path) -> TestResult<Vec<String>> {
    let subjects = run_git(worktree, &["log", "--format=%s"])?;
    Ok(subjects.lines().map(ToString::to_string).collect())
}

pub fn commit_count(worktree: &Path) -> TestResult<u64> {
    let count = run_git(worktree, &["rev-list", "--count", "HEAD"])?;
    Ok(count.parse()?)
}

pub fn files_in_last_commit(worktree: &Path) -> TestResult<BTreeSet<String>> {
    let arguments = ["show", "--name-only", "--format=", "HEAD"];
    Ok(listed_files(&run_git(worktree, &arguments)?))
}

pub fn remaining_changes(worktree: &Path) -> TestResult<BTreeSet<String>> {
    let tracked = run_git(worktree, &["diff", "HEAD", "--name-only"])?;
    let untracked_arguments = ["ls-files", "--others", "--exclude-standard"];
    let untracked = run_git(worktree, &untracked_arguments)?;
    let mut remaining = listed_files(&tracked);
    remaining.extend(listed_files(&untracked));
    Ok(remaining)
}

pub fn committed_agents_file(worktree: &Path) -> TestResult<Option<String>> {
    let listing_arguments =
        ["ls-tree", "--name-only", "HEAD", AGENTS_FILE_NAME];
    if run_git(worktree, &listing_arguments)?.is_empty() {
        return Ok(None);
    }
    let committed_path = format!("HEAD:{AGENTS_FILE_NAME}");
    Ok(Some(run_git(worktree, &["show", &committed_path])?))
}

pub fn leftover_changes(
    created_file_count: Range<usize>,
) -> impl Strategy<Value = LeftoverChanges> {
    let parts = (
        vec(tracked_file_change(), TRACKED_FILES.len()),
        btree_set(CREATED_FILE_NAMES, created_file_count),
        rules_markdown(),
        project_agents_file(),
    );
    parts.prop_map(gather_leftover_changes)
}

fn gather_leftover_changes(parts: LeftoverChangeParts) -> LeftoverChanges {
    let (
        tracked_file_changes,
        created_files,
        rules_markdown,
        project_agents_file,
    ) = parts;
    LeftoverChanges {
        tracked_file_changes,
        created_files,
        rules_markdown,
        project_agents_file,
    }
}

fn listed_files(listing: &str) -> BTreeSet<String> {
    listing.lines().map(ToString::to_string).collect()
}

fn tracked_file_change() -> impl Strategy<Value = TrackedFileChange> {
    prop_oneof![
        Just(TrackedFileChange::Keep),
        Just(TrackedFileChange::Edit),
        Just(TrackedFileChange::Delete),
    ]
}

fn rules_markdown() -> impl Strategy<Value = String> {
    prop_oneof![Just(String::new()), RULES_MARKDOWN.prop_map(String::from)]
}

fn project_agents_file() -> impl Strategy<Value = ProjectAgentsFile> {
    prop_oneof![
        Just(ProjectAgentsFile::Tracked),
        Just(ProjectAgentsFile::Absent),
    ]
}
