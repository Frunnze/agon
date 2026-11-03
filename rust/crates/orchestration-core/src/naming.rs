use thiserror::Error;

pub const MAXIMUM_NAME_LENGTH: usize = 40;
pub const FALLBACK_PROJECT_NAME: &str = "project";
const NAME_SEPARATOR: char = '-';

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum NameProblem {
    #[error("a name cannot be empty")]
    Empty,
    #[error(
        "a name can only use lowercase letters, digits and dashes, \
         not {character:?}"
    )]
    InvalidCharacter { character: char },
    #[error(
        "a name can have at most {} characters, this one has {length}",
        MAXIMUM_NAME_LENGTH
    )]
    TooLong { length: usize },
}

pub fn validate_name(name: &str) -> Result<(), NameProblem> {
    if name.is_empty() {
        return Err(NameProblem::Empty);
    }

    let disallowed_character = name
        .chars()
        .find(|character| !is_name_character(*character));
    if let Some(character) = disallowed_character {
        return Err(NameProblem::InvalidCharacter { character });
    }

    let length = name.chars().count();
    if length > MAXIMUM_NAME_LENGTH {
        return Err(NameProblem::TooLong { length });
    }

    Ok(())
}

#[must_use]
pub fn convert_to_project_name(folder_or_repository_name: &str) -> String {
    let mut project_name = String::new();
    for character in folder_or_repository_name.to_lowercase().chars() {
        let is_kept =
            character != NAME_SEPARATOR && is_name_character(character);
        let is_after_word = !project_name.is_empty()
            && !project_name.ends_with(NAME_SEPARATOR);
        if is_kept {
            project_name.push(character);
        } else if is_after_word {
            project_name.push(NAME_SEPARATOR);
        }
    }

    let shortened: String =
        project_name.chars().take(MAXIMUM_NAME_LENGTH).collect();
    let trimmed = shortened.trim_end_matches(NAME_SEPARATOR);
    if trimmed.is_empty() {
        return FALLBACK_PROJECT_NAME.to_owned();
    }
    trimmed.to_owned()
}

fn is_name_character(character: char) -> bool {
    character.is_ascii_lowercase()
        || character.is_ascii_digit()
        || character == '-'
}
