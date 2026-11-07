use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::protected_paths::{
    PARENT_FOLDER_SEGMENT, is_same_protected_pattern, read_protected_pattern,
};

pub const MAXIMUM_PATTERN_LENGTH: usize = 200;
pub const MAXIMUM_PATTERN_COUNT: usize = 200;
pub const FORBIDDEN_PATTERN_CHARACTERS: [char; 5] =
    ['"', '\'', '\\', '(', ')'];
const PATTERN_SEPARATOR: char = '/';

pub const DEFAULT_PROTECTED_PATTERNS: [&str; 50] = [
    ".env",
    ".env.*",
    "~/.ssh",
    "~/.aws",
    "~/.azure",
    "~/.config/gcloud",
    "~/.kube",
    "~/.docker",
    "~/.npmrc",
    "~/.netrc",
    "~/.gnupg",
    "~/.gitconfig",
    "~/.git-credentials",
    "~/.pgpass",
    "~/.boto",
    "~/.m2/settings.xml",
    "~/.pypirc",
    "~/.terraform.d",
    "~/.vault-token",
    "~/.condarc",
    "~/.gem/credentials",
    "~/Library/Keychains",
    "~/Library/Cookies",
    "~/.claude.json",
    "~/.claude.json.backup",
    "~/.bash_history",
    "~/.zsh_history",
    "~/.python_history",
    "~/.psql_history",
    "~/.rediscli_history",
    "~/.octave_hist",
    "~/.config/gh/hosts.yml",
    "~/.config/op",
    "~/.oci",
    "~/.putty",
    "~/.yarnrc",
    "~/.yarnrc.yml",
    "~/.erlang.cookie",
    "~/.emulator_console_auth_token",
    "~/.gradle/gradle.properties",
    "~/.streamlit/secrets.toml",
    "~/Library/Application Support/Firefox",
    "~/Library/Application Support/Google/Chrome",
    "~/Library/Application Support/BraveSoftware",
    "~/Library/Application Support/Microsoft Edge",
    "~/Library/Application Support/Vivaldi",
    "~/Library/Application Support/Opera Software",
    "~/Library/Safari",
    "~/.anydesk",
    "~/.parsec",
];

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProtectedFiles {
    pub patterns: Vec<String>,
}

impl Default for ProtectedFiles {
    fn default() -> Self {
        let patterns = DEFAULT_PROTECTED_PATTERNS
            .iter()
            .map(ToString::to_string)
            .collect();
        Self { patterns }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum ProtectedPatternProblem {
    #[error("a pattern cannot be empty")]
    Empty,
    #[error("the pattern {pattern:?} starts or ends with a space")]
    SurroundingSpace { pattern: String },
    #[error(
        "a pattern can have at most {} characters, this one has {length}",
        MAXIMUM_PATTERN_LENGTH
    )]
    TooLong { length: usize },
    #[error(
        "the pattern {pattern:?} cannot contain {character:?}: quotes, \
         backslashes and brackets are not allowed"
    )]
    ForbiddenCharacter { pattern: String, character: char },
    #[error("the pattern {pattern:?} cannot contain control characters")]
    ControlCharacter { pattern: String },
    #[error("the pattern {pattern:?} cannot use .. to leave a folder")]
    ParentFolder { pattern: String },
    #[error("the pattern {pattern:?} names no file or folder")]
    NamesNothing { pattern: String },
    #[error(
        "the pattern {pattern:?} is listed twice: it protects the same \
         files as {earlier_pattern:?}"
    )]
    Duplicate {
        pattern: String,
        earlier_pattern: String,
    },
    #[error(
        "the list can have at most {} patterns, this one has {count}",
        MAXIMUM_PATTERN_COUNT
    )]
    TooMany { count: usize },
}

pub fn validate_protected_files(
    protected: &ProtectedFiles,
) -> Result<(), ProtectedPatternProblem> {
    let count = protected.patterns.len();
    if count > MAXIMUM_PATTERN_COUNT {
        return Err(ProtectedPatternProblem::TooMany { count });
    }

    for (position, pattern) in protected.patterns.iter().enumerate() {
        validate_protected_pattern(pattern)?;
        let earlier_patterns = &protected.patterns[..position];
        let same_earlier_pattern = earlier_patterns
            .iter()
            .find(|earlier| is_same_protected_pattern(earlier, pattern));
        if let Some(earlier_pattern) = same_earlier_pattern {
            return Err(ProtectedPatternProblem::Duplicate {
                pattern: pattern.clone(),
                earlier_pattern: earlier_pattern.clone(),
            });
        }
    }
    Ok(())
}

pub fn validate_protected_pattern(
    pattern: &str,
) -> Result<(), ProtectedPatternProblem> {
    if pattern.is_empty() {
        return Err(ProtectedPatternProblem::Empty);
    }

    let owned_pattern = || pattern.to_string();
    if pattern.trim() != pattern {
        let pattern = owned_pattern();
        return Err(ProtectedPatternProblem::SurroundingSpace { pattern });
    }

    let length = pattern.chars().count();
    if length > MAXIMUM_PATTERN_LENGTH {
        return Err(ProtectedPatternProblem::TooLong { length });
    }

    let forbidden_character = pattern
        .chars()
        .find(|character| FORBIDDEN_PATTERN_CHARACTERS.contains(character));
    if let Some(character) = forbidden_character {
        let pattern = owned_pattern();
        return Err(ProtectedPatternProblem::ForbiddenCharacter {
            pattern,
            character,
        });
    }

    if pattern.chars().any(char::is_control) {
        let pattern = owned_pattern();
        return Err(ProtectedPatternProblem::ControlCharacter { pattern });
    }

    let mut segments = pattern.split(PATTERN_SEPARATOR);
    if segments.any(|segment| segment == PARENT_FOLDER_SEGMENT) {
        let pattern = owned_pattern();
        return Err(ProtectedPatternProblem::ParentFolder { pattern });
    }

    if read_protected_pattern(pattern).segments.is_empty() {
        let pattern = owned_pattern();
        return Err(ProtectedPatternProblem::NamesNothing { pattern });
    }
    Ok(())
}
