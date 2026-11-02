use thiserror::Error;

use crate::local_folders::{
    LocalFolderProblem, is_local_address, parse_local_address,
    render_local_address,
};

const SCHEME_SEPARATOR: &str = "://";
const SUPPORTED_SCHEME: &str = "https";
const SECURE_SHELL_PREFIX: &str = "git@";
const GIT_SUFFIX: &str = ".git";
const SECURE_SHELL_HOST_SEPARATOR: char = ':';
const PATH_SEPARATOR: &str = "/";
const HOST_LABEL_SEPARATOR: char = '.';
const CANONICAL_PART_COUNT: usize = 3;
const MINIMUM_HOST_LABELS: usize = 2;
const RESERVED_PATH_PARTS: [&str; 2] = [".", ".."];

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum AddressProblem {
    #[error("the repository address is empty")]
    Empty,
    #[error("only https and git@ addresses are supported, not {scheme}")]
    UnsupportedScheme { scheme: String },
    #[error("a git@ address needs a colon after the host")]
    MissingColon,
    #[error("expected host/owner/repository, found {part_count} parts")]
    WrongPartCount { part_count: usize },
    #[error("{host} is not a valid host")]
    InvalidHost { host: String },
    #[error("{part} is not a valid owner or repository name")]
    InvalidPathPart { part: String },
    #[error(transparent)]
    LocalFolder(#[from] LocalFolderProblem),
}

pub fn parse_repository_address(
    address: &str,
) -> Result<String, AddressProblem> {
    let trimmed_address = address.trim();
    if trimmed_address.is_empty() {
        return Err(AddressProblem::Empty);
    }
    if is_local_address(trimmed_address) {
        let folder = parse_local_address(trimmed_address)?;
        return Ok(render_local_address(&folder)?);
    }

    let host_and_path = remove_address_prefix(trimmed_address)?;
    let without_slashes = host_and_path.trim_end_matches(PATH_SEPARATOR);
    let without_suffix = without_slashes.trim_end_matches(GIT_SUFFIX);
    let parts: Vec<&str> = without_suffix.split(PATH_SEPARATOR).collect();
    if parts.len() != CANONICAL_PART_COUNT {
        return Err(AddressProblem::WrongPartCount {
            part_count: parts.len(),
        });
    }

    validate_host(parts[0])?;
    validate_path_part(parts[1])?;
    validate_path_part(parts[2])?;
    Ok(parts.join(PATH_SEPARATOR))
}

fn remove_address_prefix(address: &str) -> Result<String, AddressProblem> {
    if let Some((scheme, rest)) = address.split_once(SCHEME_SEPARATOR) {
        if scheme != SUPPORTED_SCHEME {
            return Err(AddressProblem::UnsupportedScheme {
                scheme: scheme.to_owned(),
            });
        }
        return Ok(rest.to_owned());
    }

    if let Some(rest) = address.strip_prefix(SECURE_SHELL_PREFIX) {
        let (host, path) = rest
            .split_once(SECURE_SHELL_HOST_SEPARATOR)
            .ok_or(AddressProblem::MissingColon)?;
        return Ok(format!("{host}{PATH_SEPARATOR}{path}"));
    }

    Ok(address.to_owned())
}

fn validate_host(host: &str) -> Result<(), AddressProblem> {
    let labels: Vec<&str> = host.split(HOST_LABEL_SEPARATOR).collect();
    let has_enough_labels = labels.len() >= MINIMUM_HOST_LABELS;
    let has_valid_labels = labels.iter().all(|label| is_host_label(label));
    if has_enough_labels && has_valid_labels {
        return Ok(());
    }
    Err(AddressProblem::InvalidHost {
        host: host.to_owned(),
    })
}

fn is_host_label(label: &str) -> bool {
    !label.is_empty() && label.chars().all(is_host_character)
}

fn is_host_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == '-'
}

fn validate_path_part(part: &str) -> Result<(), AddressProblem> {
    let is_reserved = RESERVED_PATH_PARTS.contains(&part);
    let has_valid_characters = part.chars().all(is_path_character);
    if !part.is_empty() && !is_reserved && has_valid_characters {
        return Ok(());
    }
    Err(AddressProblem::InvalidPathPart {
        part: part.to_owned(),
    })
}

fn is_path_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.')
}
