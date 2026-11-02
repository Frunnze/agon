use thiserror::Error;

pub const PATH_SEPARATOR: char = '/';
const CURRENT_FOLDER: &str = ".";
const PARENT_FOLDER: &str = "..";
const FOREIGN_SEPARATOR: char = '\\';

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum RepositoryPathProblem {
    #[error("the path {0:?} is absolute, paths start at the repository root")]
    Absolute(String),
    #[error("the path {0:?} leaves the repository")]
    LeavesRepository(String),
    #[error("the path {0:?} holds a character paths cannot hold")]
    InvalidCharacter(String),
    #[error("the file path cannot be empty")]
    EmptyFilePath,
}

pub fn normalize_folder_path(
    path: &str,
) -> Result<String, RepositoryPathProblem> {
    if path.starts_with(PATH_SEPARATOR) {
        return Err(RepositoryPathProblem::Absolute(path.to_owned()));
    }
    if path.chars().any(is_forbidden_character) {
        return Err(RepositoryPathProblem::InvalidCharacter(path.to_owned()));
    }

    let mut kept_parts = Vec::new();
    for part in path.split(PATH_SEPARATOR) {
        if part == PARENT_FOLDER {
            let path = path.to_owned();
            return Err(RepositoryPathProblem::LeavesRepository(path));
        }
        if !part.is_empty() && part != CURRENT_FOLDER {
            kept_parts.push(part);
        }
    }
    Ok(kept_parts.join(&PATH_SEPARATOR.to_string()))
}

pub fn normalize_file_path(
    path: &str,
) -> Result<String, RepositoryPathProblem> {
    let normalized = normalize_folder_path(path)?;
    if normalized.is_empty() {
        return Err(RepositoryPathProblem::EmptyFilePath);
    }
    Ok(normalized)
}

#[must_use]
pub fn split_file_path(normalized_path: &str) -> (&str, &str) {
    match normalized_path.rsplit_once(PATH_SEPARATOR) {
        Some((folder, name)) => (folder, name),
        None => ("", normalized_path),
    }
}

fn is_forbidden_character(character: char) -> bool {
    character.is_control() || character == FOREIGN_SEPARATOR
}
