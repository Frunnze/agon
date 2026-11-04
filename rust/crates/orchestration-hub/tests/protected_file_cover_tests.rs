use std::collections::BTreeMap;
use std::collections::BTreeSet;
use std::error::Error;
use std::fs;
use std::path::{Path, PathBuf};

use orchestration_core::device::SandboxKind;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::is_protected_path;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::protected_file_covers::{
    CONTAINER_HOME_DIRECTORY, cover_protected_files,
};
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, wrap_in_sandbox,
};
use orchestration_hub::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, WorkspaceMounts,
};
use proptest::collection::btree_set;
use proptest::prelude::*;
use tempfile::TempDir;

const TASK_FOLDER_NAME: &str = "task-folder";
const COVER_CASES: u32 = 24;
const READ_ONLY_OPTION: &str = ",readonly";
const SECRET_TEXT: &str = "SECRET=1\n";

type TestResult<T> = Result<T, Box<dyn Error>>;

struct TaskTree {
    _root: TempDir,
    task_folder: PathBuf,
}

fn make_task_tree(files: &[&str], folders: &[&str]) -> TestResult<TaskTree> {
    let root = TempDir::new()?;
    let task_folder = root.path().join(TASK_FOLDER_NAME);
    fs::create_dir_all(&task_folder)?;
    for folder in folders {
        fs::create_dir_all(task_folder.join(folder))?;
    }
    for file in files {
        let path = task_folder.join(file);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&path, SECRET_TEXT)?;
    }
    Ok(TaskTree {
        _root: root,
        task_folder,
    })
}

fn mounts_for(task_folder: &Path) -> WorkspaceMounts {
    WorkspaceMounts {
        task_folder: task_folder.to_path_buf(),
        git_directories: Vec::new(),
        placeholder_mounts: Vec::new(),
    }
}

fn covered_relative_paths(
    mounts: &WorkspaceMounts,
) -> TestResult<BTreeSet<String>> {
    let mut covered = BTreeSet::new();
    for placeholder_mount in &mounts.placeholder_mounts {
        let relative = placeholder_mount
            .covered_path
            .strip_prefix(&mounts.task_folder)?;
        covered.insert(relative.to_string_lossy().into_owned());
    }
    Ok(covered)
}

fn agent_command() -> CommandSpecification {
    CommandSpecification {
        program: "claude".to_owned(),
        arguments: vec!["-p".to_owned()],
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn container_mount_values(
    mounts: &WorkspaceMounts,
) -> TestResult<Vec<String>> {
    let settings = ContainerSettings {
        engine: ContainerEngine::Docker,
        image: "agon-runner".to_owned(),
    };
    let wrapped = wrap_in_sandbox(
        SandboxKind::Container,
        &settings,
        &agent_command(),
        mounts,
        &[],
    )?;
    let mut mount_values = Vec::new();
    for (position, argument) in wrapped.arguments.iter().enumerate() {
        if argument == "--mount" {
            mount_values.push(wrapped.arguments[position + 1].clone());
        }
    }
    Ok(mount_values)
}

#[test]
fn test_cover_protected_files_property_covers_matching_files_only()
-> TestResult<()> {
    let tree = make_task_tree(
        &[
            "app/.env",
            "app/.env.example",
            "app/config/.env.local",
            "app/.envrc",
            "app/src/main.rs",
            "app/production.env",
        ],
        &["app/.venv/bin"],
    )?;
    let mounts = mounts_for(&tree.task_folder);

    let covered = cover_protected_files(&mounts, &ProtectedFiles::default())?;

    let expected: BTreeSet<String> =
        ["app/.env", "app/.env.example", "app/config/.env.local"]
            .iter()
            .map(ToString::to_string)
            .collect();
    assert_eq!(covered_relative_paths(&covered)?, expected);
    Ok(())
}

#[test]
fn test_cover_protected_files_property_placeholders_are_empty()
-> TestResult<()> {
    let tree = make_task_tree(&["app/.env"], &["app/secrets/keys"])?;
    let mounts = mounts_for(&tree.task_folder);
    let protected = ProtectedFiles {
        patterns: vec![".env".to_owned(), "secrets".to_owned()],
    };

    let covered = cover_protected_files(&mounts, &protected)?;

    assert_eq!(covered.placeholder_mounts.len(), 2);
    for placeholder_mount in &covered.placeholder_mounts {
        let placeholder = &placeholder_mount.placeholder;
        assert!(!placeholder.starts_with(&tree.task_folder));
        if placeholder_mount.covered_path.is_dir() {
            assert!(placeholder.is_dir());
            assert_eq!(fs::read_dir(placeholder)?.count(), 0);
        } else {
            assert_eq!(fs::read(placeholder)?, Vec::<u8>::new());
        }
    }
    Ok(())
}

#[test]
fn test_wrap_in_sandbox_property_mounts_placeholders_read_only()
-> TestResult<()> {
    let tree = make_task_tree(&["app/.env", "app/readme.md"], &[])?;
    let mounts = mounts_for(&tree.task_folder);
    let covered = cover_protected_files(&mounts, &ProtectedFiles::default())?;

    let mount_values = container_mount_values(&covered)?;

    let placeholder = &covered.placeholder_mounts[0].placeholder;
    let expected_cover = format!(
        "type=bind,source={},target={CONTAINER_WORKSPACE_DIRECTORY}/app/.env\
         {READ_ONLY_OPTION}",
        placeholder.display()
    );
    let task_mount = format!(
        "type=bind,source={},target={CONTAINER_WORKSPACE_DIRECTORY}",
        tree.task_folder.display()
    );
    assert_eq!(mount_values, vec![task_mount, expected_cover]);
    Ok(())
}

#[test]
fn test_cover_protected_files_property_empty_list_covers_nothing()
-> TestResult<()> {
    let tree = make_task_tree(&["app/.env"], &[])?;
    let mounts = mounts_for(&tree.task_folder);
    let protected = ProtectedFiles {
        patterns: Vec::new(),
    };

    let covered = cover_protected_files(&mounts, &protected)?;

    assert_eq!(covered, mounts);
    Ok(())
}

#[test]
fn test_wrap_in_sandbox_property_local_process_ignores_placeholders()
-> TestResult<()> {
    let tree = make_task_tree(&["app/.env"], &[])?;
    let mounts = mounts_for(&tree.task_folder);
    let covered = cover_protected_files(&mounts, &ProtectedFiles::default())?;
    let settings = ContainerSettings {
        engine: ContainerEngine::Docker,
        image: String::new(),
    };

    let wrapped = wrap_in_sandbox(
        SandboxKind::LocalProcess,
        &settings,
        &agent_command(),
        &covered,
        &[],
    )?;

    assert_eq!(wrapped.program, "claude");
    assert_eq!(wrapped.arguments, vec!["-p".to_owned()]);
    Ok(())
}

fn to_case_error(problem: &dyn Error) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

fn any_tree_file() -> impl Strategy<Value = String> {
    let folder = "(app|src|config|\\.secrets|lib)";
    let name =
        "(\\.env|\\.env\\.[a-z]{1,4}|[a-z]{1,6}\\.(rs|md|pem)|\\.envrc)";
    proptest::collection::vec(folder, 0..3).prop_flat_map(move |folders| {
        name.prop_map(move |file_name| {
            let mut parts = folders.clone();
            parts.push(file_name);
            parts.join("/")
        })
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COVER_CASES))]

    #[test]
    fn test_cover_protected_files_property_covers_exactly_what_matches(
        files in btree_set(any_tree_file(), 1..10),
    ) {
        let file_names: Vec<&str> = files.iter().map(String::as_str).collect();
        let protected = ProtectedFiles {
            patterns: vec![".env".to_owned(), "*.pem".to_owned()],
        };
        let tree = make_task_tree(&file_names, &[])
            .map_err(|problem| to_case_error(&*problem))?;
        let mounts = mounts_for(&tree.task_folder);

        let covered = cover_protected_files(&mounts, &protected)
            .map_err(|problem| to_case_error(&problem))?;

        let mut expected = BTreeSet::new();
        for file in &files {
            let agent_path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{file}");
            let is_protected = is_protected_path(
                &protected,
                &agent_path,
                CONTAINER_HOME_DIRECTORY,
            );
            if is_protected {
                expected.insert(file.clone());
            }
        }
        let covered_paths =
            covered_relative_paths(&covered)
                .map_err(|problem| to_case_error(&*problem))?;
        prop_assert_eq!(covered_paths, expected);
    }
}
