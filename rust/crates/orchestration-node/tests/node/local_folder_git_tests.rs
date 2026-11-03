use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;
use tempfile::TempDir;

use crate::support::folder_checks::{check_folder, prepared_or_panic};
use crate::support::git_folders::{GIT_FOLDER_NAME, create_named_git_folder};
use crate::support::git_origin::run_git;
use crate::support::test_device::{describe, fail};

type FolderFiles = BTreeMap<String, String>;

const GIT_CASES: u32 = 6;
const FOLDER_NAME_PATTERN: &str = "[a-z][a-z0-9]{0,8}";
const BRANCH_PATTERN: &str = "[a-z][a-z0-9-]{0,8}[a-z0-9]";
const FILE_NAME_PATTERN: &str = "[a-z][a-z0-9]{0,6}\\.txt";
const FILE_TEXT_PATTERN: &str = "[a-z ]{0,20}";
const MOST_FILES: usize = 4;
const STARTED_BRANCH: &str = "main";
const INNER_FOLDER_NAME: &str = "inner";
const FOLDER_OWNER_NAME: &str = "Folder Owner";

fn folder_files_strategy() -> impl Strategy<Value = FolderFiles> {
    proptest::collection::btree_map(
        FILE_NAME_PATTERN,
        FILE_TEXT_PATTERN,
        0..=MOST_FILES,
    )
}

fn write_files(folder: &Path, files: &FolderFiles) -> Result<(), String> {
    fs::create_dir_all(folder).map_err(describe)?;
    for (file_name, file_text) in files {
        fs::write(folder.join(file_name), file_text).map_err(describe)?;
    }
    Ok(())
}

fn list_committed_files(folder: &Path) -> Result<Vec<String>, String> {
    let listed = run_git(folder, &["ls-tree", "-r", "--name-only", "HEAD"])?;
    let mut committed_files = Vec::new();
    for file_name in listed.lines() {
        committed_files.push(file_name.to_owned());
    }
    Ok(committed_files)
}

fn list_file_names(files: &FolderFiles) -> Vec<String> {
    files.keys().cloned().collect()
}

fn count_commits(folder: &Path) -> Result<String, String> {
    run_git(folder, &["rev-list", "--count", "HEAD"])
}

fn read_current_branch(folder: &Path) -> Result<String, String> {
    run_git(folder, &["symbolic-ref", "--short", "HEAD"])
}

fn read_latest_subject(folder: &Path) -> Result<String, String> {
    run_git(folder, &["log", "-1", "--format=%s"])
}

fn read_working_state(folder: &Path) -> Result<String, String> {
    let head = run_git(folder, &["rev-parse", "HEAD"])?;
    let status = run_git(folder, &["status", "--porcelain"])?;
    Ok(format!("{head}\n{status}"))
}

#[test]
fn test_check_local_folder_property_starts_git_in_a_folder_without_it() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(GIT_CASES));
    let strategy = (FOLDER_NAME_PATTERN, folder_files_strategy());

    let outcome = runner.run(&strategy, |(name, files)| {
        let parent = TempDir::new().map_err(fail)?;
        let folder = parent.path().join(&name);
        write_files(&folder, &files).map_err(fail)?;

        let checked = check_folder(&prepared, &folder.display().to_string())
            .map_err(fail)?;

        prop_assert_eq!(&checked["has_started_git"], &json!(true));
        prop_assert_eq!(&checked["default_branch"], &json!(STARTED_BRANCH));
        prop_assert_eq!(
            read_current_branch(&folder).map_err(fail)?,
            STARTED_BRANCH
        );
        prop_assert_eq!(count_commits(&folder).map_err(fail)?, "1");
        prop_assert_eq!(
            list_committed_files(&folder).map_err(fail)?,
            list_file_names(&files)
        );
        let expected_subject = format!("Start {name}");
        prop_assert_eq!(
            read_latest_subject(&folder).map_err(fail)?,
            expected_subject
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_local_folder_property_gives_an_empty_repository_a_commit() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(GIT_CASES));
    let strategy = (BRANCH_PATTERN, folder_files_strategy());

    let outcome = runner.run(&strategy, |(branch, files)| {
        let parent = TempDir::new().map_err(fail)?;
        let folder = parent.path().join(INNER_FOLDER_NAME);
        write_files(&folder, &files).map_err(fail)?;
        let initial_branch = format!("--initial-branch={branch}");
        run_git(&folder, &["init", "--quiet", &initial_branch])
            .map_err(fail)?;
        run_git(&folder, &["config", "user.name", FOLDER_OWNER_NAME])
            .map_err(fail)?;

        let checked = check_folder(&prepared, &folder.display().to_string())
            .map_err(fail)?;

        prop_assert_eq!(&checked["has_started_git"], &json!(true));
        prop_assert_eq!(&checked["default_branch"], &json!(STARTED_BRANCH));
        prop_assert_eq!(
            read_current_branch(&folder).map_err(fail)?,
            STARTED_BRANCH
        );
        prop_assert_eq!(count_commits(&folder).map_err(fail)?, "1");
        prop_assert_eq!(
            list_committed_files(&folder).map_err(fail)?,
            list_file_names(&files)
        );
        let author =
            run_git(&folder, &["log", "-1", "--format=%an"]).map_err(fail)?;
        prop_assert_eq!(author, FOLDER_OWNER_NAME);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_local_folder_property_leaves_a_folder_with_commits_untouched() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(GIT_CASES));
    let strategy = (BRANCH_PATTERN, folder_files_strategy());

    let outcome = runner.run(&strategy, |(branch, files)| {
        let parent = TempDir::new().map_err(fail)?;
        let folder =
            create_named_git_folder(parent.path(), INNER_FOLDER_NAME, &branch)
                .map_err(fail)?;
        write_files(&folder, &files).map_err(fail)?;
        let state_before = read_working_state(&folder).map_err(fail)?;

        let checked = check_folder(&prepared, &folder.display().to_string())
            .map_err(fail)?;

        prop_assert_eq!(&checked["has_started_git"], &json!(false));
        prop_assert_eq!(&checked["default_branch"], &json!(branch));
        prop_assert_eq!(
            read_working_state(&folder).map_err(fail)?,
            state_before
        );
        prop_assert_eq!(count_commits(&folder).map_err(fail)?, "1");
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_local_folder_property_refuses_a_folder_inside_a_repository() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(GIT_CASES));
    let strategy = (FOLDER_NAME_PATTERN, folder_files_strategy());

    let outcome = runner.run(&strategy, |(name, files)| {
        let parent = TempDir::new().map_err(fail)?;
        let repository =
            create_named_git_folder(parent.path(), &name, STARTED_BRANCH)
                .map_err(fail)?;
        let inner_folder = repository.join(INNER_FOLDER_NAME);
        write_files(&inner_folder, &files).map_err(fail)?;
        let state_before = read_working_state(&repository).map_err(fail)?;
        let inner_path = inner_folder.display().to_string();

        let refused = check_folder(&prepared, &inner_path);

        let expected =
            format!("the folder {inner_path} is not a git repository");
        prop_assert_eq!(refused, Err(expected));
        prop_assert!(!inner_folder.join(GIT_FOLDER_NAME).exists());
        prop_assert_eq!(
            read_working_state(&repository).map_err(fail)?,
            state_before
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
