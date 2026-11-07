use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::{
    ANY_FOLDERS_SEGMENT, is_protected_path,
};
use proptest::collection::vec;
use proptest::prelude::*;

const HOME: &str = "/home/agent";
const ANY_CHARACTERS: char = '*';
const ONE_CHARACTER: char = '?';
const MAXIMUM_SEGMENTS: usize = 4;

fn glob() -> impl Strategy<Value = String> {
    "[aAb*?]{1,5}"
}

fn name() -> impl Strategy<Value = String> {
    "[aAb\u{e9}]{1,5}"
}

fn segment_glob() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(ANY_FOLDERS_SEGMENT.to_owned()),
        Just("a".to_owned()),
        Just("b".to_owned()),
        Just("a*".to_owned()),
    ]
}

fn path_name() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("a".to_owned()),
        Just("b".to_owned()),
        Just("ab".to_owned()),
    ]
}

fn reference_glob_matches(glob: &[char], name: &[char]) -> bool {
    let Some(first_glob) = glob.first() else {
        return name.is_empty();
    };
    let rest_of_glob = &glob[1..];
    if *first_glob == ANY_CHARACTERS {
        let swallows_nothing = reference_glob_matches(rest_of_glob, name);
        let swallows_one =
            !name.is_empty() && reference_glob_matches(glob, &name[1..]);
        return swallows_nothing || swallows_one;
    }
    let Some(first_name) = name.first() else {
        return false;
    };
    let is_same_character = *first_glob == ONE_CHARACTER
        || first_glob.eq_ignore_ascii_case(first_name);
    is_same_character && reference_glob_matches(rest_of_glob, &name[1..])
}

fn reference_segments_match(pattern: &[String], path: &[String]) -> bool {
    let Some(first_pattern) = pattern.first() else {
        return true;
    };
    let rest_of_pattern = &pattern[1..];
    if first_pattern == ANY_FOLDERS_SEGMENT {
        let spans_nothing = reference_segments_match(rest_of_pattern, path);
        let spans_one =
            !path.is_empty() && reference_segments_match(pattern, &path[1..]);
        return spans_nothing || spans_one;
    }
    let Some(first_path) = path.first() else {
        return false;
    };
    let glob_characters: Vec<char> = first_pattern.chars().collect();
    let name_characters: Vec<char> = first_path.chars().collect();
    reference_glob_matches(&glob_characters, &name_characters)
        && reference_segments_match(rest_of_pattern, &path[1..])
}

fn from_root(pattern: &str) -> ProtectedFiles {
    ProtectedFiles {
        patterns: vec![format!("/{pattern}")],
    }
}

proptest! {
    #[test]
    fn test_matches_segment_glob_property_agrees_with_a_reference_glob(
        glob in glob(),
        name in name(),
    ) {
        let glob_characters: Vec<char> = glob.chars().collect();
        let name_characters: Vec<char> = name.chars().collect();

        let is_protected =
            is_protected_path(&from_root(&glob), &format!("/{name}"), HOME);

        prop_assert_eq!(
            is_protected,
            reference_glob_matches(&glob_characters, &name_characters)
        );
    }

    #[test]
    fn test_matches_segment_glob_property_star_stays_inside_one_name(
        middle in "[a-z.]{0,6}",
        folder in "[a-z]{1,4}",
    ) {
        let protected = from_root("pre*suf");

        let one_name = format!("/pre{middle}suf");
        let across_names = format!("/pre/{folder}/suf");

        prop_assert!(is_protected_path(&protected, &one_name, HOME));
        prop_assert!(!is_protected_path(&protected, &across_names, HOME));
    }

    #[test]
    fn test_matches_segment_glob_property_question_mark_is_one_character(
        character in any::<char>().prop_filter(
            "a separator splits the name",
            |character| *character != '/',
        ),
    ) {
        let protected = from_root("a?c");

        let one_character = format!("/a{character}c");
        let two_characters = format!("/a{character}{character}c");

        prop_assert!(is_protected_path(&protected, &one_character, HOME));
        prop_assert!(!is_protected_path(&protected, "/ac", HOME));
        prop_assert!(!is_protected_path(&protected, &two_characters, HOME));
    }

    #[test]
    fn test_matches_leading_segments_property_agrees_with_a_reference(
        pattern in vec(segment_glob(), 1..MAXIMUM_SEGMENTS),
        path in vec(path_name(), 0..MAXIMUM_SEGMENTS + 2),
    ) {
        let is_protected = is_protected_path(
            &from_root(&pattern.join("/")),
            &format!("/{}", path.join("/")),
            HOME,
        );

        let is_reference_match = reference_segments_match(&pattern, &path);
        prop_assert_eq!(is_protected, is_reference_match);
    }

    #[test]
    fn test_matches_leading_segments_property_protects_what_is_inside(
        pattern in vec(segment_glob(), 1..MAXIMUM_SEGMENTS),
        path in vec(path_name(), 1..MAXIMUM_SEGMENTS),
        inside in vec(path_name(), 1..MAXIMUM_SEGMENTS),
    ) {
        let protected = from_root(&pattern.join("/"));
        let outer_path = format!("/{}", path.join("/"));
        let inner_path = format!("{outer_path}/{}", inside.join("/"));

        if is_protected_path(&protected, &outer_path, HOME) {
            prop_assert!(is_protected_path(&protected, &inner_path, HOME));
        }
    }

    #[test]
    fn test_matches_leading_segments_property_needs_every_named_segment(
        names in vec("[a-z]{1,4}", 2..MAXIMUM_SEGMENTS),
    ) {
        let protected = from_root(&names.join("/"));
        let parent = format!("/{}", names[..names.len() - 1].join("/"));

        prop_assert!(!is_protected_path(&protected, &parent, HOME));
    }

    #[test]
    fn test_matches_leading_segments_property_double_star_spans_folders(
        between in vec("[a-z]{1,4}", 0..MAXIMUM_SEGMENTS),
    ) {
        let protected = from_root("start/**/end");
        let mut path = "/start".to_owned();
        for folder in &between {
            path.push('/');
            path.push_str(folder);
        }
        path.push_str("/end");

        prop_assert!(is_protected_path(&protected, &path, HOME));
    }
}
