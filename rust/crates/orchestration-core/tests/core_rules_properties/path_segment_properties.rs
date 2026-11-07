use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::is_protected_path;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::protected_path_support::{
    HOME, absolute, insert_after, path_segments, pattern_list,
};

proptest! {
    #[test]
    fn test_split_path_segments_property_ignores_redundant_separators(
        protected in pattern_list(),
        segments in path_segments(),
        position in any::<prop::sample::Index>(),
        inserted in prop_oneof![Just(""), Just(".")],
    ) {
        let plain_path = absolute(&segments);
        let padded_segments = insert_after(&segments, position, &[inserted]);
        let padded_path = absolute(&padded_segments);

        prop_assert_eq!(
            is_protected_path(&protected, &padded_path, HOME),
            is_protected_path(&protected, &plain_path, HOME)
        );
    }

    #[test]
    fn test_split_path_segments_property_ignores_trailing_separators(
        protected in pattern_list(),
        segments in path_segments(),
        trailing in "/{1,3}",
        home_trailing in "/{0,2}",
    ) {
        let plain_path = absolute(&segments);
        let trailing_path = format!("{plain_path}{trailing}");
        let trailing_home = format!("{HOME}{home_trailing}");

        prop_assert_eq!(
            is_protected_path(&protected, &trailing_path, &trailing_home),
            is_protected_path(&protected, &plain_path, HOME)
        );
    }

    #[test]
    fn test_split_path_segments_property_ignores_dot_parts_in_the_home(
        protected in pattern_list(),
        segments in path_segments(),
        home_padding in prop_oneof![Just("/"), Just("/./"), Just("//")],
    ) {
        let path = absolute(&segments);
        let padded_home = HOME.replacen('/', home_padding, 2);

        prop_assert_eq!(
            is_protected_path(&protected, &path, &padded_home),
            is_protected_path(&protected, &path, HOME)
        );
    }

    #[test]
    fn test_strip_leading_segments_property_home_matches_whole_names(
        suffix in "[a-z]{1,4}",
        inside in path_segments(),
    ) {
        let protected = ProtectedFiles {
            patterns: vec!["~/.ssh".to_owned()],
        };
        let inside_path = inside.join("/");

        let under_home = format!("{HOME}/.ssh/{inside_path}");
        let beside_home = format!("{HOME}{suffix}/.ssh/{inside_path}");

        prop_assert!(is_protected_path(&protected, &under_home, HOME));
        prop_assert!(!is_protected_path(&protected, &beside_home, HOME));
    }

    #[test]
    fn test_strip_leading_segments_property_ignores_ascii_case_of_home(
        inside in path_segments(),
        uppercase_mask in vec(any::<bool>(), HOME.len()),
    ) {
        let protected = ProtectedFiles {
            patterns: vec!["~/.ssh".to_owned()],
        };
        let mut written_home = String::new();
        for (character, is_upper) in HOME.chars().zip(&uppercase_mask) {
            if *is_upper {
                written_home.push(character.to_ascii_uppercase());
            } else {
                written_home.push(character);
            }
        }
        let path = format!("{written_home}/.ssh/{}", inside.join("/"));

        prop_assert!(is_protected_path(&protected, &path, HOME));
    }

    #[test]
    fn test_strip_leading_segments_property_home_and_above_stay_open(
        pattern in "~/[a-z.]{1,5}",
        kept_segments in 0_usize..3,
    ) {
        let protected = ProtectedFiles { patterns: vec![pattern] };
        let home_segments: Vec<&str> =
            HOME.split('/').filter(|segment| !segment.is_empty()).collect();
        let ancestor_segments = home_segments[..kept_segments].join("/");
        let ancestor = format!("/{ancestor_segments}");

        prop_assert!(!is_protected_path(&protected, &ancestor, HOME));
    }

    #[test]
    fn test_matches_pattern_property_root_patterns_anchor_at_the_root(
        segments in path_segments(),
        prefix in "[0-9]{1,3}",
    ) {
        let pattern = absolute(&segments);
        let protected = ProtectedFiles { patterns: vec![pattern.clone()] };
        let moved = format!("/{prefix}{pattern}");

        prop_assert!(is_protected_path(&protected, &pattern, HOME));
        prop_assert!(!is_protected_path(&protected, &moved, HOME));
    }

    #[test]
    fn test_matches_pattern_property_depth_patterns_survive_any_prefix(
        protected in pattern_list(),
        segments in path_segments(),
        prefix in path_segments(),
    ) {
        let depth_only = ProtectedFiles {
            patterns: protected
                .patterns
                .into_iter()
                .filter(|pattern| {
                    !pattern.starts_with('/') && !pattern.starts_with('~')
                })
                .collect(),
        };
        let path = absolute(&segments);
        let deeper_path = format!("{}{path}", absolute(&prefix));

        if is_protected_path(&depth_only, &path, HOME) {
            prop_assert!(is_protected_path(&depth_only, &deeper_path, HOME));
        }
    }

    #[test]
    fn test_matches_pattern_property_home_patterns_follow_the_home(
        segments in path_segments(),
        other_home in "/[0-9]{1,5}",
    ) {
        let pattern = format!("~/{}", segments.join("/"));
        let protected = ProtectedFiles { patterns: vec![pattern] };
        let path = format!("{HOME}/{}", segments.join("/"));

        prop_assert!(is_protected_path(&protected, &path, HOME));
        prop_assert!(!is_protected_path(&protected, &path, &other_home));
    }
}
