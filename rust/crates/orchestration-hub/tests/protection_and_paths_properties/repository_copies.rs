use std::collections::BTreeMap;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};

use orchestration_core::repository_files::{
    RepositoryBranches, RepositoryEntry, RepositoryFile,
};
use orchestration_hub::repository_reading::RepositoryReader;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::git_support::run_git;
use crate::hook_running::to_case_error;

pub type CaseResult<T> = Result<T, TestCaseError>;
pub type FileTree = BTreeMap<String, Vec<u8>>;

pub const REPOSITORY_CASES: u32 = 12;
pub const MAIN_BRANCH: &str = "main";

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const COPY_FOLDER_PREFIX: &str = "protection-repository-";
const COPY_FOLDER_NAME: &str = "copy";
const REMOTE_PREFIX: &str = "refs/remotes/origin/";
const REMOTE_HEAD: &str = "refs/remotes/origin/HEAD";

#[derive(Debug)]
pub struct RepositoryCopy {
    pub _temporary: TempDir,
    pub root: PathBuf,
}

impl RepositoryCopy {
    pub fn git(&self, arguments: &[&str]) -> CaseResult<String> {
        run_git(&self.root, arguments).map_err(to_case_error)
    }

    pub fn open_reader(&self) -> CaseResult<RepositoryReader> {
        RepositoryReader::open(&self.root).map_err(to_case_error)
    }

    pub fn commit_tree(&self, files: &FileTree) -> CaseResult<String> {
        for (path, content) in files {
            write_file(&self.root, path, content)?;
        }
        self.git(&["add", "--all"])?;
        self.git(&["commit", "--allow-empty", "--message", "Change"])?;
        self.git(&["rev-parse", "HEAD"])
    }

    pub fn add_link(&self, name: &str, target: &str) -> CaseResult<()> {
        symlink(target, self.root.join(name)).map_err(to_case_error)
    }

    pub fn point_remote(&self, branch: &str, commit: &str) -> CaseResult<()> {
        let reference = format!("{REMOTE_PREFIX}{branch}");
        self.git(&["update-ref", &reference, commit])?;
        Ok(())
    }

    pub fn point_remote_head(&self, branch: &str) -> CaseResult<()> {
        let target = format!("{REMOTE_PREFIX}{branch}");
        self.git(&["symbolic-ref", REMOTE_HEAD, &target])?;
        Ok(())
    }
}

pub fn list_branches(
    reader: &RepositoryReader,
) -> CaseResult<RepositoryBranches> {
    reader.list_branches().map_err(to_case_error)
}

pub fn list_main_folder(
    reader: &RepositoryReader,
    folder: &str,
) -> CaseResult<Vec<RepositoryEntry>> {
    reader
        .list_folder(MAIN_BRANCH, folder)
        .map_err(to_case_error)
}

pub fn read_main_file(
    reader: &RepositoryReader,
    path: &str,
) -> CaseResult<RepositoryFile> {
    reader.read_file(MAIN_BRANCH, path).map_err(to_case_error)
}

pub fn create_empty_folder() -> CaseResult<TempDir> {
    tempfile::Builder::new()
        .prefix(COPY_FOLDER_PREFIX)
        .tempdir_in(TARGET_TEMPORARY_FOLDER)
        .map_err(to_case_error)
}

pub fn create_repository() -> CaseResult<RepositoryCopy> {
    let temporary = create_empty_folder()?;
    let root = temporary.path().join(COPY_FOLDER_NAME);
    fs::create_dir(&root).map_err(to_case_error)?;
    let initial_branch = format!("--initial-branch={MAIN_BRANCH}");
    run_git(&root, &["init", &initial_branch]).map_err(to_case_error)?;
    Ok(RepositoryCopy {
        _temporary: temporary,
        root,
    })
}

pub fn write_file(root: &Path, path: &str, content: &[u8]) -> CaseResult<()> {
    let target = root.join(path);
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent).map_err(to_case_error)?;
    }
    fs::write(target, content).map_err(to_case_error)
}

pub fn any_file_tree() -> impl Strategy<Value = FileTree> {
    let folder = prop_oneof![Just("src"), Just("docs"), Just("Assets")];
    let name = "[a-zA-Z0-9][a-zA-Z0-9 ._é中-]{0,8}";
    let path =
        (proptest::option::of(folder), name).prop_map(|(folder, name)| {
            match folder {
                Some(folder) => format!("{folder}/{name}"),
                None => name,
            }
        });
    let content = "[a-z ]{0,40}".prop_map(String::into_bytes);
    proptest::collection::btree_map(path, content, 1..6).prop_filter(
        "a name is one file or one folder, in any letter case",
        |files| {
            let names: Vec<String> =
                files.keys().map(|name| name.to_lowercase()).collect();
            names.iter().enumerate().all(|(index, name)| {
                let folder_prefix = format!("{name}/");
                let others = names.iter().skip(index + 1);
                let mut clashing_others = others.filter(|other| {
                    *other == name || other.starts_with(&folder_prefix)
                });
                let is_folder_of_earlier = names[..index]
                    .iter()
                    .any(|earlier| name.starts_with(&format!("{earlier}/")));
                clashing_others.next().is_none() && !is_folder_of_earlier
            })
        },
    )
}

pub fn list_direct_children(
    files: &FileTree,
    folder: &str,
) -> BTreeMap<String, bool> {
    let prefix = if folder.is_empty() {
        String::new()
    } else {
        format!("{folder}/")
    };
    let mut children = BTreeMap::new();
    for path in files.keys() {
        let Some(inside) = path.strip_prefix(&prefix) else {
            continue;
        };
        match inside.split_once('/') {
            Some((child_folder, _)) => {
                children.insert(child_folder.to_owned(), true);
            }
            None => {
                children.insert(inside.to_owned(), false);
            }
        }
    }
    children
}
