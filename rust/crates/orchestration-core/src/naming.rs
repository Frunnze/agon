use thiserror::Error;

pub const MAXIMUM_NAME_LENGTH: usize = 40;

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

fn is_name_character(character: char) -> bool {
    character.is_ascii_lowercase()
        || character.is_ascii_digit()
        || character == '-'
}
