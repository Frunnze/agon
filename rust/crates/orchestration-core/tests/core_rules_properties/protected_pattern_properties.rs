use orchestration_core::protected_files::{
    FORBIDDEN_PATTERN_CHARACTERS, MAXIMUM_PATTERN_LENGTH, ProtectedFiles,
    validate_protected_files, validate_protected_pattern,
};
use orchestration_core::protected_paths::{
    ANY_FOLDERS_SEGMENT, PatternPlace, ProtectedPattern, is_protected_path,
    read_protected_pattern,
};
use proptest::collection::vec;
use proptest::prelude::*;

const HOME: &str = "/home/agent";
const WORKSPACE: &str = "/workspace";
const HOME_PREFIX: &str = "~/";
const ROOT_PREFIX: &str = "/";
const SEPARATOR: &str = "/";
const MAXIMUM_SEGMENTS: usize = 4;

fn pattern_text() -> impl Strategy<Value = String> {
    prop_oneof![
        "(~|~/|/)?[a-z.*?]{0,4}(/[a-z.*?]{0,4}){0,3}/?",
        "[ \t]?(~/)?[a-z.\"'()\\\\]{0,6}[ ]?",
        ".{0,12}",
    ]
}

fn plain_segment() -> impl Strategy<Value = String> {
    "[a-z][a-z._-]{0,6}"
}

fn read_by_hand(pattern: &str) -> (PatternPlace, Vec<String>) {
    let (place, rest) = if pattern == "~" {
        (PatternPlace::UnderHome, "")
    } else if let Some(rest) = pattern.strip_prefix(HOME_PREFIX) {
        (PatternPlace::UnderHome, rest)
    } else if let Some(rest) = pattern.strip_prefix(ROOT_PREFIX) {
        (PatternPlace::FromRoot, rest)
    } else {
        (PatternPlace::AtAnyDepth, pattern)
    };
    let mut segments = Vec::new();
    for segment in rest.split(SEPARATOR) {
        if !segment.is_empty() && segment != "." {
            segments.push(segment.to_owned());
        }
    }
    (place, segments)
}

fn is_model_pattern(pattern: &str) -> bool {
    let has_forbidden_character = pattern.chars().any(|character| {
        FORBIDDEN_PATTERN_CHARACTERS.contains(&character)
            || character.is_control()
    });
    let leaves_a_folder =
        pattern.split(SEPARATOR).any(|segment| segment == "..");
    let (_, segments) = read_by_hand(pattern);
    !pattern.is_empty()
        && pattern.trim() == pattern
        && pattern.chars().count() <= MAXIMUM_PATTERN_LENGTH
        && !has_forbidden_character
        && !leaves_a_folder
        && !segments.is_empty()
}

fn example_path(pattern: &ProtectedPattern) -> String {
    let start = match pattern.place {
        PatternPlace::UnderHome => HOME,
        PatternPlace::FromRoot => "",
        PatternPlace::AtAnyDepth => WORKSPACE,
    };
    let mut path = start.to_owned();
    for segment in &pattern.segments {
        let name = if segment == ANY_FOLDERS_SEGMENT {
            "deep".to_owned()
        } else {
            segment.replace('*', "star").replace('?', "q")
        };
        path.push_str(SEPARATOR);
        path.push_str(&name);
    }
    path
}

fn only(pattern: &str) -> ProtectedFiles {
    ProtectedFiles {
        patterns: vec![pattern.to_owned()],
    }
}

proptest! {
    #[test]
    fn test_validate_protected_pattern_property_matches_the_pattern_rules(
        pattern in pattern_text(),
    ) {
        let verdict = validate_protected_pattern(&pattern);

        prop_assert_eq!(verdict.is_ok(), is_model_pattern(&pattern));
    }

    #[test]
    fn test_validate_protected_pattern_property_agrees_with_a_one_item_list(
        pattern in pattern_text(),
    ) {
        prop_assert_eq!(
            validate_protected_pattern(&pattern),
            validate_protected_files(&only(&pattern))
        );
    }

    #[test]
    fn test_validate_protected_pattern_property_accepted_ones_protect_a_path(
        pattern in pattern_text(),
    ) {
        if validate_protected_pattern(&pattern).is_err() {
            return Ok(());
        }
        let path = example_path(&read_protected_pattern(&pattern));

        prop_assert!(is_protected_path(&only(&pattern), &path, HOME));
    }

    #[test]
    fn test_protected_files_default_property_protects_each_named_path(
        position in any::<prop::sample::Index>(),
    ) {
        let defaults = ProtectedFiles::default();
        let pattern_count = defaults.patterns.len();
        let pattern = &defaults.patterns[position.index(pattern_count)];

        let path = example_path(&read_protected_pattern(pattern));

        prop_assert!(is_protected_path(&defaults, &path, HOME));
        prop_assert!(!is_protected_path(&defaults, WORKSPACE, HOME));
    }

    #[test]
    fn test_read_protected_pattern_property_reads_place_and_segments(
        pattern in pattern_text(),
    ) {
        let read_pattern = read_protected_pattern(&pattern);
        let (place, segments) = read_by_hand(&pattern);

        prop_assert_eq!(read_pattern.place, place);
        prop_assert_eq!(read_pattern.segments, segments);
    }

    #[test]
    fn test_read_protected_pattern_property_skips_empty_and_dot_segments(
        prefix in prop_oneof![Just(""), Just(HOME_PREFIX), Just(ROOT_PREFIX)],
        segments in vec(plain_segment(), 1..MAXIMUM_SEGMENTS),
        fillers in vec(prop_oneof![Just("/"), Just("/./"), Just("//")],
            MAXIMUM_SEGMENTS),
    ) {
        let plain_pattern = format!("{prefix}{}", segments.join(SEPARATOR));
        let mut padded_pattern = format!("{prefix}{}", segments[0]);
        for (segment, filler) in segments[1..].iter().zip(&fillers) {
            padded_pattern.push_str(filler);
            padded_pattern.push_str(segment);
        }
        padded_pattern.push_str(fillers[MAXIMUM_SEGMENTS - 1]);

        prop_assert_eq!(
            read_protected_pattern(&padded_pattern),
            read_protected_pattern(&plain_pattern)
        );
    }

    #[test]
    fn test_read_protected_pattern_property_segments_are_plain_names(
        pattern in ".{0,20}",
    ) {
        let read_pattern = read_protected_pattern(&pattern);

        for segment in &read_pattern.segments {
            prop_assert!(!segment.is_empty());
            prop_assert!(!segment.contains(SEPARATOR));
            prop_assert_ne!(segment.as_str(), ".");
        }
    }
}
