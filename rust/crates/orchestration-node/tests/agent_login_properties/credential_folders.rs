use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use orchestration_node::agent_credentials::AgentCredentials;
use orchestration_node::identity_store::{FileIdentityStore, IdentityStore};
use proptest::test_runner::TestCaseError;
use tempfile::{Builder, TempDir};

use crate::support::test_device::{describe, fail};

pub const CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
const IDENTITY_FILE_NAME: &str = "device-identity.key";
const NODE_FOLDER_NAME: &str = "node";
const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");

#[derive(Debug)]
pub struct NodeFolder {
    pub path: PathBuf,
    _root: TempDir,
}

pub fn create_node_folder() -> Result<NodeFolder, TestCaseError> {
    let root = Builder::new()
        .tempdir_in(TARGET_TEMPORARY_FOLDER)
        .map_err(fail)?;
    let path = root.path().join(NODE_FOLDER_NAME);
    fs::create_dir(&path).map_err(fail)?;
    Ok(NodeFolder { path, _root: root })
}

pub fn open_store(folder: &Path) -> Arc<dyn IdentityStore> {
    Arc::new(FileIdentityStore::new(folder.join(IDENTITY_FILE_NAME)))
}

pub fn open_credentials(
    folder: &Path,
) -> Result<AgentCredentials, TestCaseError> {
    AgentCredentials::open(open_store(folder)).map_err(fail)
}

pub fn find_credential_file(folder: &Path) -> PathBuf {
    folder.join(CREDENTIAL_FILE_NAME)
}

pub fn write_credential_file(
    folder: &Path,
    file_text: &str,
) -> Result<(), TestCaseError> {
    fs::write(find_credential_file(folder), file_text).map_err(fail)
}

pub fn replace_folder_with_a_file(folder: &Path) -> Result<(), TestCaseError> {
    fs::remove_dir_all(folder).map_err(fail)?;
    fs::write(folder, b"").map_err(fail)
}

pub fn list_files_containing(
    folder: &Path,
    needle: &str,
) -> Result<Vec<PathBuf>, String> {
    let mut found_files = Vec::new();
    for entry in fs::read_dir(folder).map_err(describe)? {
        let entry_path = entry.map_err(describe)?.path();
        if entry_path.is_dir() {
            found_files.extend(list_files_containing(&entry_path, needle)?);
            continue;
        }
        let file_bytes = fs::read(&entry_path).map_err(describe)?;
        if String::from_utf8_lossy(&file_bytes).contains(needle) {
            found_files.push(entry_path);
        }
    }
    Ok(found_files)
}
