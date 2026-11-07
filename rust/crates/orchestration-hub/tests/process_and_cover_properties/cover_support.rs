use std::fs;
use std::path::{Path, PathBuf};

use orchestration_core::protected_files::ProtectedFiles;
use orchestration_hub::protected_file_covers::cover_protected_files;
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::target_folders::{create_target_folder, fail_with};

pub const KEY_PATTERN: &str = "*.pem";
pub const SECRETS_FOLDER: &str = "secrets";
const TASK_FOLDER_NAME: &str = "task-folder";
const SECRET_TEXT: &str = "SECRET=1\n";

pub struct TaskTree {
    pub root: TempDir,
    pub task_folder: PathBuf,
}

pub fn protect(patterns: &[&str]) -> ProtectedFiles {
    ProtectedFiles {
        patterns: patterns.iter().map(ToString::to_string).collect(),
    }
}

pub fn make_task_tree(
    files: &[String],
    folders: &[String],
) -> Result<TaskTree, TestCaseError> {
    let root = create_target_folder()?;
    let task_folder = root.path().join(TASK_FOLDER_NAME);
    fs::create_dir_all(&task_folder).map_err(|problem| fail_with(&problem))?;
    for folder in folders {
        fs::create_dir_all(task_folder.join(folder))
            .map_err(|problem| fail_with(&problem))?;
    }
    for file in files {
        let path = task_folder.join(file);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .map_err(|problem| fail_with(&problem))?;
        }
        fs::write(&path, SECRET_TEXT)
            .map_err(|problem| fail_with(&problem))?;
    }
    Ok(TaskTree { root, task_folder })
}

pub fn mounts_for(task_folder: &Path) -> WorkspaceMounts {
    WorkspaceMounts {
        task_folder: task_folder.to_path_buf(),
        git_directories: Vec::new(),
        placeholder_mounts: Vec::new(),
    }
}

pub fn cover_or_fail(
    task_folder: &Path,
    protected: &ProtectedFiles,
) -> Result<WorkspaceMounts, TestCaseError> {
    cover_protected_files(&mounts_for(task_folder), protected)
        .map_err(|problem| fail_with(&problem))
}

pub fn covered_relative_paths(
    mounts: &WorkspaceMounts,
) -> Result<Vec<String>, TestCaseError> {
    let mut covered = Vec::new();
    for placeholder_mount in &mounts.placeholder_mounts {
        let relative = placeholder_mount
            .covered_path
            .strip_prefix(&mounts.task_folder)
            .map_err(|problem| fail_with(&problem))?;
        covered.push(relative.to_string_lossy().into_owned());
    }
    Ok(covered)
}

pub fn any_plain_name() -> impl Strategy<Value = String> {
    "[a-z0-9é中_-][a-z0-9é中 _.-]{0,10}".prop_filter(
        "a name no pattern protects",
        |name| {
            let lowercase_name = name.to_lowercase();
            let extension = lowercase_name.rsplit_once('.');
            let is_key = extension.is_some_and(|(_, ending)| ending == "pem");
            !is_key && lowercase_name != SECRETS_FOLDER
        },
    )
}

pub fn any_relative_folder() -> impl Strategy<Value = String> {
    proptest::collection::vec(any_plain_name(), 0..3)
        .prop_map(|names| names.join("/"))
}

pub fn join_relative(folder: &str, name: &str) -> String {
    if folder.is_empty() {
        return name.to_owned();
    }
    if name.is_empty() {
        return folder.to_owned();
    }
    format!("{folder}/{name}")
}
