use std::fs::{self, File};
use std::io;
use std::path::{Path, PathBuf};

use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::is_protected_path;

use crate::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, PlaceholderMount, WorkspaceMounts,
};

pub const PLACEHOLDER_FOLDER_NAME: &str = "protected-file-placeholders";
const CONTAINER_HOMES_FOLDER_NAME: &str = "home";
const CONTAINER_USER_NAME: &str = "agent";
const EMPTY_FILE_NAME: &str = "empty-file";
const EMPTY_FOLDER_NAME: &str = "empty-folder";
const AGENT_PATH_SEPARATOR: &str = "/";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EntryKind {
    File,
    Folder,
}

struct ProtectedEntry {
    path: PathBuf,
    kind: EntryKind,
}

struct Placeholders {
    empty_file: PathBuf,
    empty_folder: PathBuf,
}

#[must_use]
pub fn container_home_directory() -> String {
    format!(
        "{AGENT_PATH_SEPARATOR}{CONTAINER_HOMES_FOLDER_NAME}\
         {AGENT_PATH_SEPARATOR}{CONTAINER_USER_NAME}"
    )
}

pub fn cover_protected_files(
    mounts: &WorkspaceMounts,
    protected: &ProtectedFiles,
) -> io::Result<WorkspaceMounts> {
    if protected.patterns.is_empty() {
        return Ok(mounts.clone());
    }
    let protected_entries =
        find_protected_entries(&mounts.task_folder, protected)?;
    if protected_entries.is_empty() {
        return Ok(mounts.clone());
    }

    let placeholders = prepare_placeholders(&mounts.task_folder)?;
    let mut placeholder_mounts = mounts.placeholder_mounts.clone();
    for entry in protected_entries {
        let placeholder = match entry.kind {
            EntryKind::File => placeholders.empty_file.clone(),
            EntryKind::Folder => placeholders.empty_folder.clone(),
        };
        placeholder_mounts.push(PlaceholderMount {
            covered_path: entry.path,
            placeholder,
        });
    }
    Ok(WorkspaceMounts {
        placeholder_mounts,
        ..mounts.clone()
    })
}

fn find_protected_entries(
    task_folder: &Path,
    protected: &ProtectedFiles,
) -> io::Result<Vec<ProtectedEntry>> {
    let home_directory = container_home_directory();
    let mut protected_entries = Vec::new();
    let mut folders_to_read = vec![task_folder.to_path_buf()];
    while let Some(folder) = folders_to_read.pop() {
        for directory_entry in fs::read_dir(&folder)? {
            let directory_entry = directory_entry?;
            let path = directory_entry.path();
            let agent_path = describe_agent_path(task_folder, &path);
            let is_protected =
                is_protected_path(protected, &agent_path, &home_directory);
            if is_protected {
                if let Some(kind) = read_entry_kind(&path) {
                    protected_entries.push(ProtectedEntry { path, kind });
                }
                continue;
            }
            if directory_entry.file_type()?.is_dir() {
                folders_to_read.push(path);
            }
        }
    }
    protected_entries.sort_by(|first, second| first.path.cmp(&second.path));
    Ok(protected_entries)
}

fn describe_agent_path(task_folder: &Path, path: &Path) -> String {
    let relative = path.strip_prefix(task_folder).unwrap_or(path);
    let mut agent_path = CONTAINER_WORKSPACE_DIRECTORY.to_string();
    for component in relative.components() {
        agent_path.push_str(AGENT_PATH_SEPARATOR);
        agent_path.push_str(&component.as_os_str().to_string_lossy());
    }
    agent_path
}

fn read_entry_kind(path: &Path) -> Option<EntryKind> {
    let metadata = fs::metadata(path).ok()?;
    if metadata.is_dir() {
        return Some(EntryKind::Folder);
    }
    Some(EntryKind::File)
}

fn prepare_placeholders(task_folder: &Path) -> io::Result<Placeholders> {
    let parent = task_folder.parent().ok_or_else(|| {
        io::Error::other("the task folder has no parent folder")
    })?;
    let placeholder_folder = parent.join(PLACEHOLDER_FOLDER_NAME);
    let empty_folder = placeholder_folder.join(EMPTY_FOLDER_NAME);
    fs::create_dir_all(&empty_folder)?;
    let empty_file = placeholder_folder.join(EMPTY_FILE_NAME);
    File::create(&empty_file)?;
    Ok(Placeholders {
        empty_file,
        empty_folder,
    })
}
