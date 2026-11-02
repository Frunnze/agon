use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use thiserror::Error;

pub const AGENTS_FILE_NAME: &str = "AGENTS.md";

const LINE_BREAK: &str = "\n";
const BLANK_LINE: &str = "\n\n";
const NO_SEPARATOR: &str = "";

#[derive(Debug, Error)]
pub enum AgentsFileError {
    #[error("{0:?} is not a plain file, so the rules were not written")]
    NotPlainFile(PathBuf),
    #[error("could not read or write {path:?}: {source}")]
    Access {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
}

#[must_use]
pub fn merge_agents_markdown(
    project_markdown: &str,
    rules_markdown: &str,
) -> String {
    if project_markdown.ends_with(rules_markdown) {
        return project_markdown.to_string();
    }
    let separator = separator_after(project_markdown);
    format!("{project_markdown}{separator}{rules_markdown}")
}

pub fn write_agents_file(
    worktree: &Path,
    rules_markdown: &str,
) -> Result<(), AgentsFileError> {
    if rules_markdown.is_empty() {
        return Ok(());
    }

    let path = worktree.join(AGENTS_FILE_NAME);
    let project_markdown = read_project_markdown(&path)?;
    let merged = merge_agents_markdown(&project_markdown, rules_markdown);
    fs::write(&path, merged).map_err(|source| access_error(&path, source))
}

fn separator_after(project_markdown: &str) -> &'static str {
    let has_blank_line_ending = project_markdown.ends_with(BLANK_LINE);
    if project_markdown.is_empty() || has_blank_line_ending {
        return NO_SEPARATOR;
    }
    if project_markdown.ends_with(LINE_BREAK) {
        return LINE_BREAK;
    }
    BLANK_LINE
}

fn read_project_markdown(path: &Path) -> Result<String, AgentsFileError> {
    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => {
            return Ok(String::new());
        }
        Err(problem) => return Err(access_error(path, problem)),
    };

    if !metadata.is_file() {
        return Err(AgentsFileError::NotPlainFile(path.to_path_buf()));
    }
    fs::read_to_string(path).map_err(|source| access_error(path, source))
}

fn access_error(path: &Path, source: io::Error) -> AgentsFileError {
    AgentsFileError::Access {
        path: path.to_path_buf(),
        source,
    }
}
