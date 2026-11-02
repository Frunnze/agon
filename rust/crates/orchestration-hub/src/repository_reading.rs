use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

use orchestration_core::repository_files::{
    FilePreview, RepositoryBranches, RepositoryEntry, RepositoryEntryKind,
    RepositoryFile, order_repository_entries,
};
use orchestration_core::repository_paths::{
    RepositoryPathProblem, normalize_file_path, normalize_folder_path,
    split_file_path,
};
use thiserror::Error;

use crate::branch_names::TASK_BRANCH_PREFIX;
use crate::file_previews::{
    MAXIMUM_IMAGE_PREVIEW_BYTES, describe_file_preview,
};
use crate::tree_records::{TreeRecord, parse_tree_record};
use crate::workspace_mounts::GIT_DIRECTORY_NAME;

const GIT_PROGRAM: &str = "git";
const GIT_DIRECTORY_VARIABLE: &str = "GIT_DIR";
const TERMINAL_PROMPT_VARIABLE: &str = "GIT_TERMINAL_PROMPT";
const OPTIONAL_LOCKS_VARIABLE: &str = "GIT_OPTIONAL_LOCKS";
const SWITCHED_OFF: &str = "0";
const LOCAL_BRANCHES: &str = "refs/heads/";
const REMOTE_BRANCHES: &str = "refs/remotes/origin/";
const REMOTE_HEAD: &str = "HEAD";
const BRANCH_LISTING: [&str; 6] = [
    "for-each-ref",
    "--sort=refname",
    "--sort=-committerdate",
    "--format=%(refname)",
    "refs/heads",
    "refs/remotes/origin",
];
const TREE_LISTING: [&str; 3] = ["ls-tree", "--long", "-z"];
const BLOB_READING: [&str; 2] = ["cat-file", "blob"];
const TREE_PATH_SEPARATOR: char = ':';
const RECORD_SEPARATOR: char = '\0';
const LINE_SEPARATOR: char = '\n';
const ARGUMENT_SEPARATOR: &str = " ";

#[derive(Debug, Error)]
pub enum RepositoryReadError {
    #[error(transparent)]
    Path(#[from] RepositoryPathProblem),
    #[error("this runner has no copy of the repository")]
    NoCopy,
    #[error("the branch {0} is not on this runner")]
    UnknownBranch(String),
    #[error("{0:?} is not a folder on this branch")]
    NotAFolder(String),
    #[error("{0} is not on this branch")]
    NotFound(String),
    #[error("{0} is a folder, not a file")]
    NotAFile(String),
    #[error("could not start git: {0}")]
    StartGit(#[source] io::Error),
    #[error("git {arguments} failed: {output}")]
    GitFailed { arguments: String, output: String },
    #[error("git gave an answer that cannot be read: {0}")]
    UnreadableAnswer(String),
}

#[derive(Debug)]
pub struct RepositoryReader {
    git_directory: PathBuf,
}

impl RepositoryReader {
    pub fn open(cached_clone: &Path) -> Result<Self, RepositoryReadError> {
        let git_directory = cached_clone.join(GIT_DIRECTORY_NAME);
        if !git_directory.is_dir() {
            return Err(RepositoryReadError::NoCopy);
        }
        Ok(Self { git_directory })
    }

    pub fn list_branches(
        &self,
    ) -> Result<RepositoryBranches, RepositoryReadError> {
        let mut branches = RepositoryBranches::default();
        for reference in self.list_references()? {
            let Some(name) = name_branch(&reference) else {
                continue;
            };
            let group = if name.starts_with(TASK_BRANCH_PREFIX) {
                &mut branches.task_branches
            } else {
                &mut branches.branches
            };
            if !group.iter().any(|listed| listed == name) {
                group.push(name.to_owned());
            }
        }
        Ok(branches)
    }

    pub fn list_folder(
        &self,
        branch: &str,
        folder: &str,
    ) -> Result<Vec<RepositoryEntry>, RepositoryReadError> {
        let folder = normalize_folder_path(folder)?;
        let reference = self.find_branch_reference(branch)?;
        let records = self.read_tree(&reference, &folder)?;
        let entries: Vec<RepositoryEntry> =
            records.into_iter().map(|record| record.entry).collect();
        Ok(order_repository_entries(&entries))
    }

    pub fn read_file(
        &self,
        branch: &str,
        path: &str,
    ) -> Result<RepositoryFile, RepositoryReadError> {
        let path = normalize_file_path(path)?;
        let reference = self.find_branch_reference(branch)?;
        let (folder, name) = split_file_path(&path);
        let records = match self.read_tree(&reference, folder) {
            Ok(records) => records,
            Err(RepositoryReadError::NotAFolder(_)) => {
                return Err(RepositoryReadError::NotFound(path));
            }
            Err(problem) => return Err(problem),
        };
        let found =
            records.into_iter().find(|record| record.entry.name == name);
        let Some(record) = found else {
            return Err(RepositoryReadError::NotFound(path));
        };

        let size = record.entry.size.unwrap_or_default();
        let preview = match record.entry.kind {
            RepositoryEntryKind::Folder => {
                return Err(RepositoryReadError::NotAFile(path));
            }
            RepositoryEntryKind::Link => FilePreview::Link,
            RepositoryEntryKind::File
                if size > MAXIMUM_IMAGE_PREVIEW_BYTES =>
            {
                FilePreview::TooLarge
            }
            RepositoryEntryKind::File => {
                let content = self.run_git(&BLOB_READING, &record.object)?;
                describe_file_preview(&content)
            }
        };
        Ok(RepositoryFile {
            path,
            size,
            preview,
        })
    }

    fn list_references(&self) -> Result<Vec<String>, RepositoryReadError> {
        let listing = self.run_git_with(&BRANCH_LISTING)?;
        let text = decode_text(&listing)?;
        let references = text
            .split(LINE_SEPARATOR)
            .filter(|line| !line.is_empty())
            .map(str::to_owned)
            .collect();
        Ok(references)
    }

    fn find_branch_reference(
        &self,
        branch: &str,
    ) -> Result<String, RepositoryReadError> {
        let local = format!("{LOCAL_BRANCHES}{branch}");
        let remote = format!("{REMOTE_BRANCHES}{branch}");
        let candidates = if branch.starts_with(TASK_BRANCH_PREFIX) {
            [local, remote]
        } else {
            [remote, local]
        };
        let references = self.list_references()?;
        candidates
            .into_iter()
            .find(|candidate| references.contains(candidate))
            .ok_or_else(|| RepositoryReadError::UnknownBranch(branch.into()))
    }

    fn read_tree(
        &self,
        reference: &str,
        folder: &str,
    ) -> Result<Vec<TreeRecord>, RepositoryReadError> {
        let tree = format!("{reference}{TREE_PATH_SEPARATOR}{folder}");
        let listing = match self.run_git(&TREE_LISTING, &tree) {
            Ok(listing) => listing,
            Err(RepositoryReadError::GitFailed { .. }) => {
                return Err(RepositoryReadError::NotAFolder(folder.into()));
            }
            Err(problem) => return Err(problem),
        };
        let text = String::from_utf8_lossy(&listing);
        let mut records = Vec::new();
        for line in text.split(RECORD_SEPARATOR) {
            if line.is_empty() {
                continue;
            }
            if let Some(record) = parse_tree_record(line)? {
                records.push(record);
            }
        }
        Ok(records)
    }

    fn run_git(
        &self,
        arguments: &[&str],
        object: &str,
    ) -> Result<Vec<u8>, RepositoryReadError> {
        let mut all_arguments = arguments.to_vec();
        all_arguments.push(object);
        self.run_git_with(&all_arguments)
    }

    fn run_git_with(
        &self,
        arguments: &[&str],
    ) -> Result<Vec<u8>, RepositoryReadError> {
        let output = Command::new(GIT_PROGRAM)
            .args(arguments)
            .env(GIT_DIRECTORY_VARIABLE, &self.git_directory)
            .env(TERMINAL_PROMPT_VARIABLE, SWITCHED_OFF)
            .env(OPTIONAL_LOCKS_VARIABLE, SWITCHED_OFF)
            .current_dir(&self.git_directory)
            .output()
            .map_err(RepositoryReadError::StartGit)?;
        if output.status.success() {
            return Ok(output.stdout);
        }
        Err(RepositoryReadError::GitFailed {
            arguments: arguments.join(ARGUMENT_SEPARATOR),
            output: String::from_utf8_lossy(&output.stderr).trim().to_owned(),
        })
    }
}

fn name_branch(reference: &str) -> Option<&str> {
    if let Some(name) = reference.strip_prefix(REMOTE_BRANCHES) {
        return (name != REMOTE_HEAD).then_some(name);
    }
    reference.strip_prefix(LOCAL_BRANCHES)
}

fn decode_text(listing: &[u8]) -> Result<&str, RepositoryReadError> {
    std::str::from_utf8(listing).map_err(|problem| {
        RepositoryReadError::UnreadableAnswer(problem.to_string())
    })
}
