use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::{
    PatternPlace, ProtectedPattern, read_protected_pattern,
};
use serde_json::json;

use crate::command_specification::CommandSpecification;
use crate::protected_files_hook::write_protected_files_hook;

pub const SETTINGS_OPTION: &str = "--settings";
pub const HOOKED_TOOLS_MATCHER: &str = concat!(
    "Bash|Read|Edit|MultiEdit|Write|Grep|Glob|LS|",
    "NotebookRead|NotebookEdit",
);
const DENIED_TOOL_KINDS: [&str; 2] = ["Read", "Edit"];
const HOME_RULE_PREFIX: &str = "~/";
const ROOT_RULE_PREFIX: &str = "//";
const ANY_DEPTH_RULE_PREFIX: &str = "**/";
const INSIDE_RULE_SUFFIX: &str = "/**";
const SEGMENT_SEPARATOR: &str = "/";
const HOOK_KIND: &str = "command";

#[must_use]
pub fn add_protected_files_settings(
    command: &CommandSpecification,
    protected: &ProtectedFiles,
) -> CommandSpecification {
    if protected.patterns.is_empty() {
        return command.clone();
    }

    let mut arguments = vec![
        SETTINGS_OPTION.to_string(),
        describe_protected_files_settings(protected),
    ];
    arguments.extend(command.arguments.iter().cloned());
    CommandSpecification {
        arguments,
        ..command.clone()
    }
}

fn describe_protected_files_settings(protected: &ProtectedFiles) -> String {
    let settings = json!({
        "permissions": { "deny": list_deny_rules(protected) },
        "hooks": {
            "PreToolUse": [{
                "matcher": HOOKED_TOOLS_MATCHER,
                "hooks": [{
                    "type": HOOK_KIND,
                    "command": write_protected_files_hook(protected),
                }],
            }],
        },
    });
    settings.to_string()
}

fn list_deny_rules(protected: &ProtectedFiles) -> Vec<String> {
    let mut deny_rules = Vec::new();
    for pattern in &protected.patterns {
        let read_pattern = read_protected_pattern(pattern);
        if read_pattern.segments.is_empty() {
            continue;
        }
        let rule_path = describe_rule_path(&read_pattern);
        let inside_rule_path = format!("{rule_path}{INSIDE_RULE_SUFFIX}");
        for tool_kind in DENIED_TOOL_KINDS {
            deny_rules.push(format!("{tool_kind}({rule_path})"));
            deny_rules.push(format!("{tool_kind}({inside_rule_path})"));
        }
    }
    deny_rules
}

fn describe_rule_path(pattern: &ProtectedPattern) -> String {
    let prefix = match pattern.place {
        PatternPlace::UnderHome => HOME_RULE_PREFIX,
        PatternPlace::FromRoot => ROOT_RULE_PREFIX,
        PatternPlace::AtAnyDepth => ANY_DEPTH_RULE_PREFIX,
    };
    let joined_segments = pattern.segments.join(SEGMENT_SEPARATOR);
    format!("{prefix}{joined_segments}")
}
