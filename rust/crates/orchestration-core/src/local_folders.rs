use thiserror::Error;

use crate::identifiers::DeviceId;
use crate::workspace::Repository;

pub const LOCAL_ADDRESS_PREFIX: &str = "local:";
const DEVICE_SEPARATOR: char = ':';
const UNIX_ROOT: &str = "/";
const FOLDER_SEPARATORS: [char; 2] = ['/', '\\'];
const DRIVE_SEPARATOR: char = ':';
const DRIVE_ROOT_LENGTH: usize = 3;
const RESERVED_FOLDER_PARTS: [&str; 2] = [".", ".."];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LocalFolder {
    pub device_id: DeviceId,
    pub path: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum LocalFolderProblem {
    #[error("the folder path is empty")]
    EmptyPath,
    #[error("the folder {0:?} is not an absolute path")]
    RelativePath(String),
    #[error(
        "the folder {0:?} has a control character, an empty part, a . or \
         a .. part"
    )]
    UnsafePath(String),
    #[error("{0:?} is not a device id")]
    InvalidDeviceId(String),
    #[error("a local address is local:<device id>:<folder>, not {0:?}")]
    MalformedAddress(String),
    #[error("the local folders of a project must all be on one computer")]
    SeveralDevices,
    #[error(
        "{0:?} cannot name a new folder: it is empty, . or .., starts or \
         ends with a space, or has a folder separator or a control character"
    )]
    UnsafeFolderName(String),
}

#[must_use]
pub fn is_local_address(address: &str) -> bool {
    address.starts_with(LOCAL_ADDRESS_PREFIX)
}

pub fn normalize_folder_path(
    path: &str,
) -> Result<String, LocalFolderProblem> {
    let trimmed_path = path.trim();
    if trimmed_path.is_empty() {
        return Err(LocalFolderProblem::EmptyPath);
    }
    let unsafe_path = || LocalFolderProblem::UnsafePath(trimmed_path.into());
    if trimmed_path.chars().any(char::is_control) {
        return Err(unsafe_path());
    }

    let Some((root, below_root)) = split_folder_root(trimmed_path) else {
        let relative_path = trimmed_path.to_owned();
        return Err(LocalFolderProblem::RelativePath(relative_path));
    };
    let parts_text = below_root.trim_end_matches(is_trailing_noise);
    let has_unsafe_part = parts_text
        .split(FOLDER_SEPARATORS)
        .any(|part| part.is_empty() || RESERVED_FOLDER_PARTS.contains(&part));
    if has_unsafe_part {
        return Err(unsafe_path());
    }
    Ok(format!("{root}{parts_text}"))
}

pub fn render_local_address(
    folder: &LocalFolder,
) -> Result<String, LocalFolderProblem> {
    validate_device_id(&folder.device_id)?;
    let path = normalize_folder_path(&folder.path)?;
    let device_text = &folder.device_id.0;
    Ok(format!(
        "{LOCAL_ADDRESS_PREFIX}{device_text}{DEVICE_SEPARATOR}{path}"
    ))
}

pub fn parse_local_address(
    address: &str,
) -> Result<LocalFolder, LocalFolderProblem> {
    let malformed = || LocalFolderProblem::MalformedAddress(address.into());
    let device_and_path = address
        .strip_prefix(LOCAL_ADDRESS_PREFIX)
        .ok_or_else(malformed)?;
    let (device_text, path) = device_and_path
        .split_once(DEVICE_SEPARATOR)
        .ok_or_else(malformed)?;

    let device_id = DeviceId(device_text.to_owned());
    validate_device_id(&device_id)?;
    let path = normalize_folder_path(path)?;
    Ok(LocalFolder { device_id, path })
}

pub fn find_folder_device(
    repositories: &[Repository],
) -> Result<Option<DeviceId>, LocalFolderProblem> {
    let mut folder_device: Option<DeviceId> = None;
    for repository in repositories {
        if !is_local_address(&repository.address) {
            continue;
        }
        let folder = parse_local_address(&repository.address)?;
        let is_other_device = folder_device
            .as_ref()
            .is_some_and(|device_id| *device_id != folder.device_id);
        if is_other_device {
            return Err(LocalFolderProblem::SeveralDevices);
        }
        folder_device = Some(folder.device_id);
    }
    Ok(folder_device)
}

pub fn validate_new_folder_name(name: &str) -> Result<(), LocalFolderProblem> {
    let is_padded = name.trim() != name;
    let is_reserved = RESERVED_FOLDER_PARTS.contains(&name);
    let has_unsafe_character = name.chars().any(|character| {
        character.is_control() || FOLDER_SEPARATORS.contains(&character)
    });
    if name.is_empty() || is_padded || is_reserved || has_unsafe_character {
        return Err(LocalFolderProblem::UnsafeFolderName(name.to_owned()));
    }
    Ok(())
}

fn validate_device_id(device_id: &DeviceId) -> Result<(), LocalFolderProblem> {
    let device_text = &device_id.0;
    let has_valid_characters = device_text.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || character == '-'
    });
    if device_text.is_empty() || !has_valid_characters {
        return Err(LocalFolderProblem::InvalidDeviceId(device_text.clone()));
    }
    Ok(())
}

fn is_trailing_noise(character: char) -> bool {
    character.is_whitespace() || FOLDER_SEPARATORS.contains(&character)
}

fn split_folder_root(path: &str) -> Option<(&str, &str)> {
    if let Some(below_root) = path.strip_prefix(UNIX_ROOT) {
        return Some((UNIX_ROOT, below_root));
    }

    let root = path.get(..DRIVE_ROOT_LENGTH)?;
    let mut root_characters = root.chars();
    let drive = root_characters.next()?;
    let drive_separator = root_characters.next()?;
    let folder_separator = root_characters.next()?;
    let is_drive_root = drive.is_ascii_alphabetic()
        && drive_separator == DRIVE_SEPARATOR
        && FOLDER_SEPARATORS.contains(&folder_separator);
    if !is_drive_root {
        return None;
    }
    Some((root, &path[DRIVE_ROOT_LENGTH..]))
}
