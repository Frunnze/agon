use std::collections::BTreeMap;

use orchestration_core::protected_files::ProtectedFiles;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::protected_files_settings::{
    SETTINGS_OPTION, add_protected_files_settings,
};
use proptest::collection::btree_set;
use proptest::prelude::*;
use serde_json::Value;

const HOOKED_TOOLS: [&str; 6] =
    ["Bash", "Read", "Edit", "Write", "Grep", "Glob"];

fn any_protected_files() -> impl Strategy<Value = ProtectedFiles> {
    let pattern = concat!(
        "~/\\.[a-z]{1,8}|[a-z]{1,8}\\.pem|",
        "/[a-z]{1,6}/[a-z]{1,6}|\\.[a-z]{2,6}",
    );
    btree_set(pattern, 1..8).prop_map(|patterns| ProtectedFiles {
        patterns: patterns.into_iter().collect(),
    })
}

fn any_arguments() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec("[a-z-]{1,12}", 0..6)
}

fn claude_command(arguments: Vec<String>) -> CommandSpecification {
    CommandSpecification {
        program: "claude".to_owned(),
        arguments,
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn read_settings(command: &CommandSpecification) -> Value {
    let settings_text = command.arguments.get(1).cloned().unwrap_or_default();
    serde_json::from_str(&settings_text).unwrap_or(Value::Null)
}

fn list_deny_rules(settings: &Value) -> Vec<String> {
    let rules = settings["permissions"]["deny"].as_array().cloned();
    rules
        .unwrap_or_default()
        .iter()
        .filter_map(|rule| rule.as_str().map(ToString::to_string))
        .collect()
}

fn expected_rule_paths(pattern: &str) -> [String; 2] {
    if let Some(inside_home) = pattern.strip_prefix("~/") {
        return [format!("~/{inside_home}"), format!("~/{inside_home}/**")];
    }
    if let Some(from_root) = pattern.strip_prefix('/') {
        return [format!("//{from_root}"), format!("//{from_root}/**")];
    }
    [format!("**/{pattern}"), format!("**/{pattern}/**")]
}

proptest! {
    #[test]
    fn test_add_protected_files_settings_property_denies_every_pattern(
        protected in any_protected_files(),
        arguments in any_arguments(),
    ) {
        let command = claude_command(arguments);

        let protected_command = add_protected_files_settings(
            &command,
            &protected,
        );

        let deny_rules = list_deny_rules(&read_settings(&protected_command));
        for pattern in &protected.patterns {
            for rule_path in expected_rule_paths(pattern) {
                let read_rule = format!("Read({rule_path})");
                let edit_rule = format!("Edit({rule_path})");
                prop_assert!(deny_rules.contains(&read_rule), "{read_rule}");
                prop_assert!(deny_rules.contains(&edit_rule), "{edit_rule}");
            }
        }
    }

    #[test]
    fn test_add_protected_files_settings_property_keeps_the_command(
        protected in any_protected_files(),
        arguments in any_arguments(),
    ) {
        let command = claude_command(arguments.clone());

        let protected_command = add_protected_files_settings(
            &command,
            &protected,
        );

        prop_assert_eq!(&protected_command.program, &command.program);
        prop_assert_eq!(
            protected_command.arguments.first().map(String::as_str),
            Some(SETTINGS_OPTION)
        );
        prop_assert_eq!(&protected_command.arguments[2..], &arguments[..]);
    }

    #[test]
    fn test_add_protected_files_settings_property_hooks_every_file_tool(
        protected in any_protected_files(),
    ) {
        let command = claude_command(Vec::new());

        let protected_command = add_protected_files_settings(
            &command,
            &protected,
        );

        let settings = read_settings(&protected_command);
        let hook_group = &settings["hooks"]["PreToolUse"][0];
        let matcher = hook_group["matcher"].as_str().unwrap_or_default();
        let tools: Vec<&str> = matcher.split('|').collect();
        for tool in HOOKED_TOOLS {
            prop_assert!(tools.contains(&tool), "{tool} in {matcher}");
        }
        let hook = &hook_group["hooks"][0];
        prop_assert_eq!(hook["type"].as_str(), Some("command"));
        let hook_command = hook["command"].as_str().unwrap_or_default();
        prop_assert!(!hook_command.is_empty());
    }

    #[test]
    fn test_add_protected_files_settings_property_empty_list_adds_nothing(
        arguments in any_arguments(),
    ) {
        let command = claude_command(arguments);
        let protected = ProtectedFiles { patterns: Vec::new() };

        let protected_command = add_protected_files_settings(
            &command,
            &protected,
        );

        prop_assert_eq!(protected_command, command);
    }
}

#[test]
fn test_add_protected_files_settings_property_translates_each_place() {
    let protected = ProtectedFiles {
        patterns: vec![
            "~/.ssh".to_owned(),
            ".env".to_owned(),
            "/etc/secrets".to_owned(),
        ],
    };
    let command = claude_command(vec!["-p".to_owned()]);

    let protected_command = add_protected_files_settings(&command, &protected);

    let deny_rules = list_deny_rules(&read_settings(&protected_command));
    let expected_rules = [
        "Read(~/.ssh)",
        "Read(~/.ssh/**)",
        "Edit(~/.ssh)",
        "Edit(~/.ssh/**)",
        "Read(**/.env)",
        "Read(**/.env/**)",
        "Read(//etc/secrets)",
        "Edit(//etc/secrets/**)",
    ];
    for rule in expected_rules {
        assert!(deny_rules.contains(&rule.to_owned()), "{rule}");
    }
}
