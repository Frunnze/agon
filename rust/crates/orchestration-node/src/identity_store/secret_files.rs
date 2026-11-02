use std::fs::{self, File, OpenOptions};
use std::io::{ErrorKind, Write};
use std::path::Path;

use super::IdentityStoreError;
use crate::file_removal::remove_file_if_present;

const TEMPORARY_SUFFIX: &str = "incomplete";
#[cfg(unix)]
const OWNER_ONLY_MODE: u32 = 0o600;

pub(super) fn read_secret_file(
    path: &Path,
) -> Result<Option<Vec<u8>>, IdentityStoreError> {
    match fs::read(path) {
        Ok(secret_bytes) => Ok(Some(secret_bytes)),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(None),
        Err(error) => Err(IdentityStoreError::File(error)),
    }
}

pub(super) fn remove_secret_file(
    path: &Path,
) -> Result<(), IdentityStoreError> {
    remove_file_if_present(path).map_err(IdentityStoreError::File)
}

pub(super) fn write_secret_file(
    path: &Path,
    secret: &[u8],
) -> Result<(), IdentityStoreError> {
    let temporary_path = path.with_extension(TEMPORARY_SUFFIX);
    remove_file_if_present(&temporary_path)?;
    let mut secret_file = create_owner_only_file(&temporary_path)?;
    secret_file.write_all(secret)?;
    secret_file.sync_all()?;
    fs::rename(&temporary_path, path)?;
    Ok(())
}

#[cfg(unix)]
fn create_owner_only_file(path: &Path) -> std::io::Result<File> {
    use std::os::unix::fs::OpenOptionsExt;

    OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(OWNER_ONLY_MODE)
        .open(path)
}

#[cfg(not(unix))]
fn create_owner_only_file(path: &Path) -> std::io::Result<File> {
    OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(path)
}
