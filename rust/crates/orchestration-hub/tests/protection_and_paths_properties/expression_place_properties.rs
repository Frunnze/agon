use orchestration_core::protected_paths::is_protected_path;
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::prelude::*;

use crate::hook_running::{
    HOOK_CASES, any_home, any_name, decide_command, decide_read, hook_for,
    protect,
};

fn join_path(start: &str, names: &[String]) -> String {
    let mut path = start.to_owned();
    for name in names {
        path.push('/');
        path.push_str(name);
    }
    path
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOOK_CASES))]

    #[test]
    fn test_describe_pattern_expression_property_home_names_stay_in_home(
        names in proptest::collection::vec(any_name(), 1..3),
        folders in proptest::collection::vec(any_name(), 0..2),
        home in any_home(),
    ) {
        let hook = hook_for(&[format!("~/{}", names.join("/"))]);

        let in_home = join_path(&home, &names);
        let elsewhere = join_path(
            &join_path(CONTAINER_WORKSPACE_DIRECTORY, &folders),
            &names,
        );

        prop_assert!(decide_read(&hook, &home, &in_home)?);
        prop_assert!(!decide_read(&hook, &home, &elsewhere)?);
    }

    #[test]
    fn test_describe_pattern_expression_property_root_names_start_at_root(
        names in proptest::collection::vec(any_name(), 1..3),
        folders in proptest::collection::vec(any_name(), 1..3),
        home in any_home(),
    ) {
        let patterns = [format!("/{}", names.join("/"))];
        let hook = hook_for(&patterns);

        let from_root = join_path("", &names);
        let deeper = join_path(&join_path("", &folders), &names);

        let is_deeper_protected =
            is_protected_path(&protect(&patterns), &deeper, &home);
        prop_assert!(decide_read(&hook, &home, &from_root)?);
        prop_assert_eq!(
            decide_read(&hook, &home, &deeper)?,
            is_deeper_protected,
        );
    }

    #[test]
    fn test_describe_pattern_expression_property_folders_stay_in_order(
        first in any_name(),
        second in any_name(),
        between in any_name(),
        home in any_home(),
    ) {
        prop_assume!(first != second);
        prop_assume!(between != first && between != second);
        let hook = hook_for(&[format!("{first}/{second}")]);

        let in_order = join_path(
            CONTAINER_WORKSPACE_DIRECTORY,
            &[first.clone(), second.clone()],
        );
        let reversed = join_path(
            CONTAINER_WORKSPACE_DIRECTORY,
            &[second.clone(), first.clone()],
        );
        let apart = join_path(
            CONTAINER_WORKSPACE_DIRECTORY,
            &[first.clone(), between, second.clone()],
        );

        prop_assert!(decide_read(&hook, &home, &in_order)?);
        prop_assert!(!decide_read(&hook, &home, &reversed)?);
        prop_assert!(!decide_read(&hook, &home, &apart)?);
    }

    #[test]
    fn test_describe_whole_place_expression_property_home_itself_is_kept(
        home in any_home(),
        spelling in prop_oneof![Just("~"), Just("~/"), Just("$HOME/")],
    ) {
        let hook = hook_for(&["~/**".to_owned()]);

        let command = format!("ls {spelling}");
        let home_folder = format!("{home}/");

        prop_assert!(decide_command(&hook, &home, &command)?);
        prop_assert!(decide_read(&hook, &home, &home_folder)?);
    }

    #[test]
    fn test_describe_whole_place_expression_property_home_is_only_home(
        names in proptest::collection::vec(any_name(), 1..3),
        home in any_home(),
    ) {
        let hook = hook_for(&["~/**".to_owned()]);

        let elsewhere = join_path(CONTAINER_WORKSPACE_DIRECTORY, &names);

        prop_assert!(!decide_read(&hook, &home, &elsewhere)?);
    }

    #[test]
    fn test_describe_whole_place_expression_property_everything_is_kept(
        pattern in prop_oneof![Just("**"), Just("/**"), Just("**/**")],
        names in proptest::collection::vec(any_name(), 1..4),
        home in any_home(),
    ) {
        let hook = hook_for(&[pattern.to_owned(), "unrelated.txt".to_owned()]);

        let path = join_path(CONTAINER_WORKSPACE_DIRECTORY, &names);
        let command = format!("cat {path}");

        prop_assert!(decide_read(&hook, &home, &path)?);
        prop_assert!(decide_command(&hook, &home, &command)?);
    }
}
