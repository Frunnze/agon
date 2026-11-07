use orchestration_core::protected_paths::is_protected_path;
use proptest::prelude::*;
use serde_json::json;

use crate::hook_running::{
    HOOK_CASES, any_home, any_valid_pattern, decide_command, decide_read,
    decide_tool, hook_for, protect,
};
use crate::path_spelling::{
    any_hostile_spelling, any_path_filling, respell_path, spell_protected_path,
};

fn any_spaceless_pattern() -> impl Strategy<Value = String> {
    any_valid_pattern()
        .prop_filter("names hold no spaces", |pattern| !pattern.contains(' '))
}

fn any_plain_path() -> impl Strategy<Value = String> {
    proptest::collection::vec("[a-z0-9][a-z0-9._-]{0,6}", 1..5)
        .prop_map(|names| format!("/{}", names.join("/")))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOOK_CASES))]

    #[test]
    fn test_describe_protected_expression_property_refuses_core_protected(
        patterns in proptest::collection::vec(any_valid_pattern(), 1..4),
        home in any_home(),
        filling in any_path_filling(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let pattern = chosen.get(&patterns);
        let path = spell_protected_path(pattern, &home, &filling);
        let protected = protect(&patterns);
        let hook = hook_for(&patterns);

        let is_core_protected = is_protected_path(&protected, &path, &home);
        let is_read_refused = decide_read(&hook, &home, &path)?;

        prop_assert!(!is_core_protected || is_read_refused, "{}", path);
    }

    #[test]
    fn test_describe_pattern_expression_property_refuses_hostile_spellings(
        pattern in any_valid_pattern(),
        home in any_home(),
        filling in any_path_filling(),
        spelling in any_hostile_spelling(),
        position in any::<usize>(),
    ) {
        let patterns = vec![pattern.clone()];
        let plain_path = spell_protected_path(&pattern, &home, &filling);
        let path = respell_path(&plain_path, spelling, position);
        let protected = protect(&patterns);
        let hook = hook_for(&patterns);

        let is_core_protected = is_protected_path(&protected, &path, &home);
        let is_read_refused = decide_read(&hook, &home, &path)?;
        let command = format!("cat '{path}'");
        let is_command_refused = decide_command(&hook, &home, &command)?;

        prop_assert!(!is_core_protected || is_read_refused, "{}", path);
        prop_assert!(!is_core_protected || is_command_refused, "{}", path);
    }

    #[test]
    fn test_describe_protected_expression_property_plain_paths_agree(
        patterns in proptest::collection::vec(any_spaceless_pattern(), 1..4),
        home in any_home(),
        filling in any_path_filling(),
        plain_path in any_plain_path(),
        is_derived in any::<bool>(),
    ) {
        let path = if is_derived {
            spell_protected_path(&patterns[0], &home, &filling)
        } else {
            plain_path
        };
        let protected = protect(&patterns);
        let hook = hook_for(&patterns);

        let is_core_protected = is_protected_path(&protected, &path, &home);
        let is_read_refused = decide_read(&hook, &home, &path)?;

        prop_assert_eq!(is_read_refused, is_core_protected, "{}", path);
    }

    #[test]
    fn test_describe_protected_expression_property_field_names_are_not_paths(
        pattern in prop_oneof![
            Just("*th"), Just("*and"), Just("*ob"), Just("path"),
            Just("command"), Just("*_path"), Just("glob"),
        ],
        name in "[a-z]{1,6}\\.(md|rs|txt)",
        home in any_home(),
    ) {
        let hook = hook_for(&[pattern.to_owned()]);
        let file_path = format!("/{name}");

        let is_read_refused = decide_read(&hook, &home, &file_path)?;
        let is_command_refused =
            decide_command(&hook, &home, &format!("cat /{name}"))?;
        let grep_input = json!({ "pattern": "x", "path": file_path });
        let is_grep_refused = decide_tool(&hook, &home, "Grep", &grep_input)?;

        prop_assert!(!is_read_refused);
        prop_assert!(!is_command_refused);
        prop_assert!(!is_grep_refused);
    }
}
