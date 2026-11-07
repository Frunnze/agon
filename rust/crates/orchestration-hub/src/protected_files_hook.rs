use orchestration_core::protected_files::ProtectedFiles;
use serde_json::json;

use crate::protected_file_expressions::{
    NAME_CHARACTERS, describe_protected_expression,
};

pub const REFUSAL_REASON: &str =
    "Agon refused: this file is on the list of files agents can't read.";
const NAMED_FIELDS_EXPRESSION: &str = concat!(
    r#""(tool_name|command|file_path|path|glob|notebook_path|pattern)""#,
    r#"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*""#,
);
const PATH_TIDYING_FUNCTION: &str = concat!(
    r#"function tidy(path) { gsub(/\\\\/, "", path); "#,
    r#"while (sub(/\/\.?\//, "/", path)) ; "#,
    r#"while (sub(/\/([^\/."]|\.[^\/."]|\.\.[^\/"])[^\/"]*\/\.\.\//, "#,
    r#""/", path)) ; "#,
    r#"while (match(path, "[^" name_characters "]/[.][.]/")) "#,
    r#"path = substr(path, 1, RSTART) "/" substr(path, RSTART + RLENGTH); "#,
    r#"return path } "#,
);
const HOME_NAMING_FUNCTION: &str = concat!(
    r#"function name_home(field) { "#,
    r#"sub(/^"[a-z_]*"[ \t]*:[ \t]*/, "", field); "#,
    r#"rest = tidy(field); line = ""; "#,
    r#"while (home_folder != "" && "#,
    r#"(at = index(tolower(rest), lower_home_folder)) > 0) { "#,
    r#"line = line substr(rest, 1, at - 1); "#,
    r#"before = substr(line, length(line), 1); "#,
    r#"after = substr(rest, at + length(home_folder), 1); "#,
    r#"is_home = before !~ name_character && before != "/" "#,
    r#"&& after !~ name_character; "#,
    r#"if (is_home) line = line "~"; "#,
    r#"else line = line substr(rest, at, length(home_folder)); "#,
    r#"rest = substr(rest, at + length(home_folder)) } "#,
    r#"return line rest } "#,
);
const HOME_NAMING_PROGRAM: &str = concat!(
    r#"BEGIN { home_folder = tidy(home); sub(/\/$/, "", home_folder); "#,
    r#"lower_home_folder = tolower(home_folder); "#,
    r#"name_character = "[" name_characters "]" } "#,
    r#"/^"tool_name"/ { tool = $0; next } "#,
    r#"/^"pattern"/ { patterns[++pattern_count] = $0; next } "#,
    r#"{ print name_home($0) } "#,
    r#"END { if (tool ~ /"Glob"$/) for (i = 1; i <= pattern_count; i++) "#,
    r#"print name_home(patterns[i]) }"#,
);
const HOME_VARIABLE_NAMING_SCRIPT: &str =
    r"sed 's#\$[{]\{0,1\}HOME[}]\{0,1\}/#~/#g'";
const PIPE: &str = " | ";
const LINE_BREAK: &str = "\n";
const SUCCESSFUL_EXIT: &str = "exit 0";

#[must_use]
pub fn write_protected_files_hook(protected: &ProtectedFiles) -> String {
    let Some(protected_expression) = describe_protected_expression(protected)
    else {
        return SUCCESSFUL_EXIT.to_string();
    };
    let fields_reading =
        format!("grep -oE {}", shell_words::quote(NAMED_FIELDS_EXPRESSION));
    let path_naming = format!(
        "awk -v home=\"$HOME\" -v name_characters={} '{}{}{}'",
        shell_words::quote(NAME_CHARACTERS),
        PATH_TIDYING_FUNCTION,
        HOME_NAMING_FUNCTION,
        HOME_NAMING_PROGRAM,
    );
    let protected_matching =
        format!("grep -qiE {}", shell_words::quote(&protected_expression));
    let refusal = format!(
        "printf '%s' {}",
        shell_words::quote(&describe_refusal_decision())
    );

    let checking_pipeline = [
        fields_reading.as_str(),
        path_naming.as_str(),
        HOME_VARIABLE_NAMING_SCRIPT,
        protected_matching.as_str(),
    ]
    .join(PIPE);
    let refusing_line = format!("{checking_pipeline} && {refusal}");
    [refusing_line.as_str(), SUCCESSFUL_EXIT].join(LINE_BREAK)
}

fn describe_refusal_decision() -> String {
    let decision = json!({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": REFUSAL_REASON,
        }
    });
    decision.to_string()
}
