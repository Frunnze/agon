pub const TASK_BRANCH_PREFIX: &str = "task/";
const FORBIDDEN_CHARACTERS: [char; 8] =
    [' ', '~', '^', ':', '?', '*', '[', '\\'];
const FORBIDDEN_SEQUENCES: [&str; 2] = ["..", "@{"];
const COMPONENT_SEPARATOR: char = '/';
const HIDDEN_PREFIX: char = '.';
const LOCK_SUFFIX: &str = ".lock";
const OPTION_PREFIX: char = '-';
const RESERVED_NAME: &str = "HEAD";

#[must_use]
pub fn is_valid_branch_name(name: &str) -> bool {
    let has_bad_ends = name.is_empty()
        || name.starts_with(OPTION_PREFIX)
        || name.ends_with(HIDDEN_PREFIX);
    let has_forbidden_text = FORBIDDEN_SEQUENCES
        .iter()
        .any(|sequence| name.contains(sequence))
        || name.chars().any(is_forbidden_character);
    let is_reserved = name == RESERVED_NAME;

    if has_bad_ends || has_forbidden_text || is_reserved {
        return false;
    }
    name.split(COMPONENT_SEPARATOR).all(is_valid_component)
}

fn is_forbidden_character(character: char) -> bool {
    character.is_ascii_control() || FORBIDDEN_CHARACTERS.contains(&character)
}

fn is_valid_component(component: &str) -> bool {
    !component.is_empty()
        && !component.starts_with(HIDDEN_PREFIX)
        && !component.ends_with(LOCK_SUFFIX)
}
