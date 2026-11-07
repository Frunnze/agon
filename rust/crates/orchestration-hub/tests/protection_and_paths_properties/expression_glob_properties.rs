use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::prelude::*;

use orchestration_core::protected_paths::is_protected_path;

use crate::hook_running::{
    Decision, HOOK_CASES, any_home, any_name, decide_read, hook_for, protect,
};

fn any_special_name() -> impl Strategy<Value = String> {
    "[a-z]{1,3}[.+{}|^$\\[\\]][a-z]{1,3}[.+{}|^$\\[\\]]?[a-z0-9]{0,2}"
}

fn misread_as_expression(name: &str) -> Vec<String> {
    let is_special = |character: char| !character.is_ascii_alphanumeric();
    let mut replaced = String::new();
    for character in name.chars() {
        if is_special(character) {
            replaced.push('x');
        } else {
            replaced.push(character);
        }
    }
    let before_special = name.split(is_special).next().unwrap_or_default();
    let after_special = name.rsplit(is_special).next().unwrap_or_default();
    vec![
        replaced,
        before_special.to_owned(),
        after_special.to_owned(),
    ]
}

fn agrees_with_core(
    hook: &str,
    pattern: &str,
    home: &str,
    path: &str,
) -> Decision {
    let protected = protect(&[pattern.to_owned()]);
    let is_core_protected = is_protected_path(&protected, path, home);
    let is_read_refused = decide_read(hook, home, path)?;
    Ok(is_core_protected == is_read_refused)
}

fn workspace_path(names: &[&str]) -> String {
    format!("{CONTAINER_WORKSPACE_DIRECTORY}/{}", names.join("/"))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOOK_CASES))]

    #[test]
    fn test_describe_segment_expression_property_special_names_are_literal(
        name in any_special_name(),
        home in any_home(),
    ) {
        let hook = hook_for(std::slice::from_ref(&name));

        let is_name_refused =
            decide_read(&hook, &home, &workspace_path(&[&name]))?;

        prop_assert!(is_name_refused);
        for misread in misread_as_expression(&name) {
            let path = workspace_path(&[&misread]);
            prop_assert!(agrees_with_core(&hook, &name, &home, &path)?);
        }
    }

    #[test]
    fn test_describe_segment_expression_property_one_character_is_exactly_one(
        start in any_name(),
        end in any_name(),
        middle in "[a-z0-9]{2,4}",
        home in any_home(),
    ) {
        let hook = hook_for(&[format!("{start}?{end}")]);
        let one = middle.chars().take(1).collect::<String>();

        let one_path = workspace_path(&[&format!("{start}{one}{end}")]);
        let none_path = workspace_path(&[&format!("{start}{end}")]);
        let many_path = workspace_path(&[&format!("{start}{middle}{end}")]);

        prop_assert!(decide_read(&hook, &home, &one_path)?);
        prop_assert!(!decide_read(&hook, &home, &none_path)?);
        prop_assert!(!decide_read(&hook, &home, &many_path)?);
    }

    #[test]
    fn test_describe_segment_expression_property_any_characters_stay_in_a_name(
        start in any_name(),
        end in any_name(),
        middle in "[a-z0-9]{0,5}",
        folder in any_name(),
        home in any_home(),
    ) {
        let pattern = format!("{start}*{end}");
        let hook = hook_for(std::slice::from_ref(&pattern));

        let inside_path = workspace_path(&[&format!("{start}{middle}{end}")]);
        let across_path = workspace_path(&[&start, &folder, &end]);

        prop_assert!(decide_read(&hook, &home, &inside_path)?);
        prop_assert!(agrees_with_core(&hook, &pattern, &home, &across_path)?);
    }

    #[test]
    fn test_describe_segment_expression_property_ascii_case_is_ignored(
        name in "[a-z][a-z0-9.-]{0,8}",
        home in any_home(),
    ) {
        let hook = hook_for(&[name.to_ascii_uppercase()]);

        let path = workspace_path(&[&name]);

        prop_assert!(decide_read(&hook, &home, &path)?);
    }

    #[test]
    fn test_trim_folder_wildcards_property_trailing_folders_protect_the_folder(
        place in prop_oneof![Just("~/"), Just("/"), Just("")],
        folder in any_name(),
        inner in any_name(),
        home in any_home(),
    ) {
        let hook = hook_for(&[format!("{place}{folder}/**")]);
        let start = match place {
            "~/" => home.clone(),
            "/" => String::new(),
            _ => CONTAINER_WORKSPACE_DIRECTORY.to_owned(),
        };

        let folder_path = format!("{start}/{folder}");
        let inner_path = format!("{start}/{folder}/{inner}");

        prop_assert!(decide_read(&hook, &home, &folder_path)?);
        prop_assert!(decide_read(&hook, &home, &inner_path)?);
    }

    #[test]
    fn test_trim_folder_wildcards_property_any_folders_alone_protect_all(
        place in prop_oneof![Just("~/"), Just("/")],
        inner in proptest::collection::vec(any_name(), 1..4),
        home in any_home(),
    ) {
        let hook = hook_for(&[format!("{place}**")]);
        let start = if place == "/" { String::new() } else { home.clone() };

        let path = format!("{start}/{}", inner.join("/"));

        prop_assert!(decide_read(&hook, &home, &path)?, "{}", path);
    }

    #[test]
    fn test_trim_folder_wildcards_property_home_folders_stay_under_home(
        folders in proptest::collection::vec(any_name(), 0..3),
        name in any_name(),
        home in any_home(),
    ) {
        let hook = hook_for(&[format!("~/**/{name}")]);
        let mut names = folders.clone();
        names.push(name);

        let under_home = format!("{home}/{}", names.join("/"));
        let elsewhere = format!(
            "{CONTAINER_WORKSPACE_DIRECTORY}/{}",
            names.join("/"),
        );

        prop_assert!(decide_read(&hook, &home, &under_home)?);
        prop_assert!(!decide_read(&hook, &home, &elsewhere)?);
    }
}
