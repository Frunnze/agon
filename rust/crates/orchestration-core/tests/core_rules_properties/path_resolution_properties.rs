use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::is_protected_path;
use proptest::prelude::*;

use crate::protected_path_support::{
    HOME, absolute, insert_after, path_segment, path_segments, pattern_list,
};

const PARENT_FOLDER: &str = "..";

proptest! {
    #[test]
    fn test_resolve_path_segments_property_cancels_a_folder_and_its_parent(
        protected in pattern_list(),
        segments in path_segments(),
        position in any::<prop::sample::Index>(),
        detour in path_segment(),
    ) {
        let plain_path = absolute(&segments);
        let detour_parts = [detour.as_str(), PARENT_FOLDER];
        let detour_segments = insert_after(&segments, position, &detour_parts);
        let detour_path = absolute(&detour_segments);

        prop_assert_eq!(
            is_protected_path(&protected, &detour_path, HOME),
            is_protected_path(&protected, &plain_path, HOME)
        );
    }

    #[test]
    fn test_resolve_path_segments_property_never_climbs_above_the_root(
        protected in pattern_list(),
        segments in path_segments(),
        climbs in 1_usize..4,
    ) {
        let plain_path = absolute(&segments);
        let climbs_above_root = format!("/{PARENT_FOLDER}").repeat(climbs);
        let climbing_path = format!("{climbs_above_root}{plain_path}");

        prop_assert_eq!(
            is_protected_path(&protected, &climbing_path, HOME),
            is_protected_path(&protected, &plain_path, HOME)
        );
    }

    #[test]
    fn test_resolve_path_segments_property_resolves_the_home_as_well(
        segments in path_segments(),
        detour in "[a-z]{1,4}",
    ) {
        let protected = ProtectedFiles {
            patterns: vec!["~/.ssh".to_owned()],
        };
        let detour_home = format!("{HOME}/{detour}/{PARENT_FOLDER}");
        let path = format!("{HOME}/.ssh/{}", segments.join("/"));
        let outside_home = format!("{HOME}/{detour}/.ssh");

        prop_assert!(is_protected_path(&protected, &path, &detour_home));
        prop_assert!(!is_protected_path(
            &protected,
            &outside_home,
            &detour_home
        ));
    }
}
