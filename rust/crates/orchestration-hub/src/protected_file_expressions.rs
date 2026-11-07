use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::{
    ANY_FOLDERS_SEGMENT, HOME_MARKER, PatternPlace, ProtectedPattern,
    read_protected_pattern,
};

pub(crate) const NAME_CHARACTERS: &str = "A-Za-z0-9._+@%~,-";
const ANY_NAME_CHARACTERS: &str = r#"[^/"\\]*"#;
const ONE_NAME_CHARACTER: &str = r#"[^/"\\]"#;
const ANY_FOLDERS: &str = "(.*/)?";
const HOME_PREFIX: &str = "~/";
const ROOT_PREFIX: &str = "/";
const SEPARATOR: &str = "/";
const ALTERNATIVE_SEPARATOR: &str = "|";
const ANY_CHARACTERS: char = '*';
const ONE_CHARACTER: char = '?';
const SPECIAL_CHARACTERS: &str = r".[]{}()*+?|^$\";

#[must_use]
pub(crate) fn describe_protected_expression(
    protected: &ProtectedFiles,
) -> Option<String> {
    let mut alternatives = Vec::new();
    for pattern in &protected.patterns {
        let read_pattern = read_protected_pattern(pattern);
        if !read_pattern.segments.is_empty() {
            alternatives.push(describe_pattern_expression(&read_pattern));
        }
    }
    if alternatives.is_empty() {
        return None;
    }

    let joined_alternatives = alternatives.join(ALTERNATIVE_SEPARATOR);
    Some(format!(
        "(^|[^{NAME_CHARACTERS}])({joined_alternatives})\
         ([^{NAME_CHARACTERS}]|$)"
    ))
}

fn describe_pattern_expression(pattern: &ProtectedPattern) -> String {
    let prefix = match pattern.place {
        PatternPlace::UnderHome => HOME_PREFIX,
        PatternPlace::FromRoot => ROOT_PREFIX,
        PatternPlace::AtAnyDepth => "",
    };
    let segments = trim_folder_wildcards(pattern);
    if segments.is_empty() {
        return describe_whole_place_expression(pattern.place);
    }

    let mut expression = prefix.to_string();
    let mut follows_segment = false;
    for segment in segments {
        if segment == ANY_FOLDERS_SEGMENT {
            if follows_segment {
                expression.push_str(SEPARATOR);
            }
            expression.push_str(ANY_FOLDERS);
            follows_segment = false;
            continue;
        }
        if follows_segment {
            expression.push_str(SEPARATOR);
        }
        expression.push_str(&describe_segment_expression(segment));
        follows_segment = true;
    }
    expression
}

fn describe_whole_place_expression(place: PatternPlace) -> String {
    match place {
        PatternPlace::UnderHome => HOME_MARKER.to_string(),
        PatternPlace::FromRoot | PatternPlace::AtAnyDepth => {
            ANY_NAME_CHARACTERS.to_string()
        }
    }
}

fn trim_folder_wildcards(pattern: &ProtectedPattern) -> &[String] {
    let is_folder_wildcard =
        |segment: &String| segment.as_str() == ANY_FOLDERS_SEGMENT;
    let mut segments = pattern.segments.as_slice();
    while segments.last().is_some_and(is_folder_wildcard) {
        segments = &segments[..segments.len() - 1];
    }
    let floats = pattern.place == PatternPlace::AtAnyDepth;
    while floats && segments.first().is_some_and(is_folder_wildcard) {
        segments = &segments[1..];
    }
    segments
}

fn describe_segment_expression(segment: &str) -> String {
    let mut expression = String::new();
    for character in segment.chars() {
        if character == ANY_CHARACTERS {
            expression.push_str(ANY_NAME_CHARACTERS);
        } else if character == ONE_CHARACTER {
            expression.push_str(ONE_NAME_CHARACTER);
        } else if SPECIAL_CHARACTERS.contains(character) {
            expression.push('\\');
            expression.push(character);
        } else {
            expression.push(character);
        }
    }
    expression
}
