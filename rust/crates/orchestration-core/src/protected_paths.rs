use crate::protected_files::ProtectedFiles;
use crate::wildcard_matching::{WildcardRules, matches_wildcards};

pub const HOME_MARKER: &str = "~";
pub const ANY_FOLDERS_SEGMENT: &str = "**";
const ANY_CHARACTERS: char = '*';
const ONE_CHARACTER: char = '?';
const PATH_SEPARATOR: char = '/';
const CURRENT_FOLDER_SEGMENT: &str = ".";
pub(crate) const PARENT_FOLDER_SEGMENT: &str = "..";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PatternPlace {
    UnderHome,
    FromRoot,
    AtAnyDepth,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProtectedPattern {
    pub place: PatternPlace,
    pub segments: Vec<String>,
}

#[must_use]
pub fn read_protected_pattern(pattern: &str) -> ProtectedPattern {
    let home_prefix = format!("{HOME_MARKER}{PATH_SEPARATOR}");
    let (place, rest) = if pattern == HOME_MARKER {
        (PatternPlace::UnderHome, "")
    } else if let Some(rest) = pattern.strip_prefix(&home_prefix) {
        (PatternPlace::UnderHome, rest)
    } else if let Some(rest) = pattern.strip_prefix(PATH_SEPARATOR) {
        (PatternPlace::FromRoot, rest)
    } else {
        (PatternPlace::AtAnyDepth, pattern)
    };

    ProtectedPattern {
        place,
        segments: split_path_segments(rest),
    }
}

#[must_use]
pub(crate) fn is_same_protected_pattern(
    first_pattern: &str,
    second_pattern: &str,
) -> bool {
    let first = read_protected_pattern(first_pattern);
    let second = read_protected_pattern(second_pattern);

    let is_same_place = first.place == second.place;
    let has_same_count = first.segments.len() == second.segments.len();
    let mut name_pairs = first.segments.iter().zip(&second.segments);
    let has_same_names = name_pairs.all(|(first_name, second_name)| {
        first_name.eq_ignore_ascii_case(second_name)
    });
    is_same_place && has_same_count && has_same_names
}

#[must_use]
pub fn is_protected_path(
    protected: &ProtectedFiles,
    path: &str,
    home: &str,
) -> bool {
    let path_segments = resolve_path_segments(path);
    let home_segments = resolve_path_segments(home);
    protected.patterns.iter().any(|pattern| {
        let read_pattern = read_protected_pattern(pattern);
        if read_pattern.segments.is_empty() {
            return false;
        }
        matches_pattern(&read_pattern, &path_segments, &home_segments)
    })
}

fn matches_pattern(
    pattern: &ProtectedPattern,
    path_segments: &[String],
    home_segments: &[String],
) -> bool {
    match pattern.place {
        PatternPlace::FromRoot => {
            matches_leading_segments(&pattern.segments, path_segments)
        }
        PatternPlace::UnderHome => {
            let Some(inside_home) =
                strip_leading_segments(path_segments, home_segments)
            else {
                return false;
            };
            matches_leading_segments(&pattern.segments, inside_home)
        }
        PatternPlace::AtAnyDepth => (0..path_segments.len()).any(|start| {
            let from_start = &path_segments[start..];
            matches_leading_segments(&pattern.segments, from_start)
        }),
    }
}

fn split_path_segments(path: &str) -> Vec<String> {
    let mut segments = Vec::new();
    for segment in path.split(PATH_SEPARATOR) {
        let is_kept = !segment.is_empty() && segment != CURRENT_FOLDER_SEGMENT;
        if is_kept {
            segments.push(segment.to_string());
        }
    }
    segments
}

fn resolve_path_segments(path: &str) -> Vec<String> {
    let mut resolved_segments = Vec::new();
    for segment in split_path_segments(path) {
        if segment == PARENT_FOLDER_SEGMENT {
            resolved_segments.pop();
        } else {
            resolved_segments.push(segment);
        }
    }
    resolved_segments
}

fn strip_leading_segments<'path>(
    path_segments: &'path [String],
    leading_segments: &[String],
) -> Option<&'path [String]> {
    if path_segments.len() < leading_segments.len() {
        return None;
    }
    let (start, rest) = path_segments.split_at(leading_segments.len());
    let starts_with_leading = start
        .iter()
        .zip(leading_segments)
        .all(|(segment, leading)| segment.eq_ignore_ascii_case(leading));
    starts_with_leading.then_some(rest)
}

fn matches_leading_segments(
    pattern_segments: &[String],
    path_segments: &[String],
) -> bool {
    let mut globs: Vec<&str> =
        pattern_segments.iter().map(String::as_str).collect();
    globs.push(ANY_FOLDERS_SEGMENT);
    let rules = WildcardRules {
        is_wildcard: |glob: &&str| *glob == ANY_FOLDERS_SEGMENT,
        matches_one: |glob: &&str, segment: &String| {
            matches_segment_glob(glob, segment)
        },
    };
    matches_wildcards(&globs, path_segments, &rules)
}

fn matches_segment_glob(glob: &str, name: &str) -> bool {
    let glob_characters: Vec<char> = glob.chars().collect();
    let name_characters: Vec<char> = name.chars().collect();
    let rules = WildcardRules {
        is_wildcard: |glob: &char| *glob == ANY_CHARACTERS,
        matches_one: |glob: &char, character: &char| {
            *glob == ONE_CHARACTER || glob.eq_ignore_ascii_case(character)
        },
    };
    matches_wildcards(&glob_characters, &name_characters, &rules)
}
