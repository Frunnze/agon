use std::collections::BTreeMap;

use orchestration_core::protected_paths::{
    PatternPlace, read_protected_pattern,
};
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::protected_files_hook::write_protected_files_hook;
use orchestration_hub::protected_files_settings::{
    HOOKED_TOOLS_MATCHER, SETTINGS_OPTION, add_protected_files_settings,
};
use proptest::prelude::*;
use serde_json::Value;

use crate::hook_running::{any_valid_pattern, protect, to_case_error};

const DENIED_TOOL_KINDS: [&str; 2] = ["Read", "Edit"];
const RULES_PER_PATTERN: usize = 4;

fn any_command() -> impl Strategy<Value = CommandSpecification> {
    let arguments = proptest::collection::vec("\\PC{0,12}", 0..5);
    ("[a-z]{1,8}", arguments).prop_map(|(program, arguments)| {
        CommandSpecification {
            program,
            arguments,
            environment: BTreeMap::new(),
            working_directory: None,
        }
    })
}

fn read_settings(
    patterns: &[String],
    command: &CommandSpecification,
) -> Result<Value, TestCaseError> {
    let settled = add_protected_files_settings(command, &protect(patterns));
    let settings_text = settled
        .arguments
        .get(1)
        .ok_or_else(|| to_case_error("no settings were added"))?;
    serde_json::from_str(settings_text).map_err(to_case_error)
}

fn read_deny_rules(settings: &Value) -> Vec<String> {
    let mut rules = Vec::new();
    let listed = settings["permissions"]["deny"].as_array();
    for rule in listed.into_iter().flatten() {
        rules.push(rule.as_str().unwrap_or_default().to_owned());
    }
    rules
}

fn expected_rule_path(pattern: &str) -> String {
    let read_pattern = read_protected_pattern(pattern);
    let joined = read_pattern.segments.join("/");
    match read_pattern.place {
        PatternPlace::UnderHome => format!("~/{joined}"),
        PatternPlace::FromRoot => format!("//{joined}"),
        PatternPlace::AtAnyDepth => format!("**/{joined}"),
    }
}

fn any_spelled_pattern() -> impl Strategy<Value = (String, String)> {
    let noise = prop_oneof![Just("/"), Just("/./"), Just("//")];
    (any_valid_pattern(), noise).prop_map(|(pattern, noise)| {
        let spelled = pattern.replacen('/', noise, 1);
        (pattern, spelled)
    })
}

proptest! {
    #[test]
    fn test_describe_protected_files_settings_property_hook_is_the_hook(
        patterns in proptest::collection::vec(any_valid_pattern(), 1..5),
        command in any_command(),
    ) {
        let settings = read_settings(&patterns, &command)?;

        let pre_tool_use = &settings["hooks"]["PreToolUse"][0];
        let hook = &pre_tool_use["hooks"][0];
        let expected_hook = write_protected_files_hook(&protect(&patterns));

        prop_assert_eq!(&pre_tool_use["matcher"], HOOKED_TOOLS_MATCHER);
        prop_assert_eq!(&hook["type"], "command");
        let hook_command = hook["command"].as_str();
        prop_assert_eq!(hook_command, Some(expected_hook.as_str()));
    }

    #[test]
    fn test_describe_protected_files_settings_property_settings_come_first(
        patterns in proptest::collection::vec(any_valid_pattern(), 1..5),
        command in any_command(),
    ) {
        let protected = protect(&patterns);

        let settled = add_protected_files_settings(&command, &protected);

        prop_assert_eq!(settled.arguments.len(), command.arguments.len() + 2);
        prop_assert_eq!(&settled.arguments[0], SETTINGS_OPTION);
        prop_assert_eq!(&settled.arguments[2..], &command.arguments[..]);
        prop_assert_eq!(&settled.program, &command.program);
    }

    #[test]
    fn test_describe_protected_files_settings_property_is_compact_json(
        patterns in proptest::collection::vec(any_valid_pattern(), 1..5),
        command in any_command(),
    ) {
        let protected = protect(&patterns);

        let settled = add_protected_files_settings(&command, &protected);

        let settings_text = &settled.arguments[1];
        let settings: Value =
            serde_json::from_str(settings_text).map_err(to_case_error)?;

        prop_assert_eq!(&settings.to_string(), settings_text);
        prop_assert!(!settings_text.contains('\n'));
    }

    #[test]
    fn test_list_deny_rules_property_four_rules_for_each_pattern(
        patterns in proptest::collection::vec(any_valid_pattern(), 1..6),
        command in any_command(),
    ) {
        let settings = read_settings(&patterns, &command)?;

        let rules = read_deny_rules(&settings);

        prop_assert_eq!(rules.len(), patterns.len() * RULES_PER_PATTERN);
    }

    #[test]
    fn test_list_deny_rules_property_rules_follow_pattern_order(
        patterns in proptest::collection::vec(any_valid_pattern(), 1..6),
        command in any_command(),
    ) {
        let settings = read_settings(&patterns, &command)?;

        let rules = read_deny_rules(&settings);

        let chunks = rules.chunks(RULES_PER_PATTERN);
        for (pattern, chunk) in patterns.iter().zip(chunks) {
            let rule_path = expected_rule_path(pattern);
            let mut expected = Vec::new();
            for tool_kind in DENIED_TOOL_KINDS {
                expected.push(format!("{tool_kind}({rule_path})"));
                expected.push(format!("{tool_kind}({rule_path}/**)"));
            }
            prop_assert_eq!(chunk, &expected[..]);
        }
    }

    #[test]
    fn test_list_deny_rules_property_nameless_patterns_add_no_rules(
        patterns in proptest::collection::vec(any_valid_pattern(), 0..4),
        nameless in proptest::collection::vec(
            prop_oneof![Just("~"), Just("/"), Just("."), Just("./.")],
            1..4,
        ),
        command in any_command(),
    ) {
        let mut listed = patterns.clone();
        listed.extend(nameless.iter().map(ToString::to_string));
        let settings = read_settings(&listed, &command)?;

        let rules = read_deny_rules(&settings);

        prop_assert_eq!(rules.len(), patterns.len() * RULES_PER_PATTERN);
    }

    #[test]
    fn test_describe_rule_path_property_place_sets_the_prefix(
        pattern in any_valid_pattern(),
        command in any_command(),
    ) {
        let patterns = [pattern.clone()];
        let settings = read_settings(&patterns, &command)?;

        let rules = read_deny_rules(&settings);
        let rule_path = expected_rule_path(&pattern);

        prop_assert_eq!(&rules[0], &format!("Read({rule_path})"));
        let has_prefix = ["~/", "//", "**/"]
            .iter()
            .any(|prefix| rule_path.starts_with(prefix));
        prop_assert!(has_prefix);
    }

    #[test]
    fn test_describe_rule_path_property_spelling_does_not_change_the_rule(
        (pattern, spelled) in any_spelled_pattern(),
        command in any_command(),
    ) {
        let plain = read_settings(&[pattern], &command)?;
        let respelled = read_settings(&[spelled], &command)?;

        prop_assert_eq!(read_deny_rules(&plain), read_deny_rules(&respelled));
    }

    #[test]
    fn test_describe_rule_path_property_rules_hold_no_empty_segments(
        pattern in any_valid_pattern(),
        command in any_command(),
    ) {
        let patterns = [pattern.clone()];
        let settings = read_settings(&patterns, &command)?;

        for rule in read_deny_rules(&settings) {
            let inner = rule.trim_start_matches("Read(")
                .trim_start_matches("Edit(")
                .trim_end_matches(')');
            let without_root = inner.trim_start_matches("//");
            prop_assert!(!without_root.contains("//"), "{}", rule);
            prop_assert!(!without_root.contains("/./"), "{}", rule);
        }
    }
}
