use std::fs;
use std::os::unix::fs::symlink;

use orchestration_runner::agents_file::{
    AGENTS_FILE_NAME, AgentsFileError, merge_agents_markdown,
    write_agents_file,
};
use proptest::option;
use proptest::prelude::*;

use crate::support::{TestResult, to_case_error};

const RULES: &str = "# Rules\n\n- Never push to main.\n  Ask first.\n";

fn any_rules() -> impl Strategy<Value = String> {
    "[a-zA-Z ]{1,20}".prop_map(|title| format!("# Rules\n\n- {title}.\n"))
}

fn any_project_markdown() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        "[a-zA-Z #]{1,40}",
        "[a-zA-Z #]{1,40}\n",
        "[a-zA-Z #]{1,40}\n\n",
    ]
}

#[test]
fn keeps_the_project_file_and_adds_the_rules_under_it() {
    let merged = merge_agents_markdown("# Project\nUse pnpm.\n", RULES);

    let expected = "# Project\nUse pnpm.\n\n# Rules\n\n\
        - Never push to main.\n  Ask first.\n";
    assert_eq!(merged, expected);
}

#[test]
fn refuses_to_write_through_a_linked_file() -> TestResult<()> {
    let worktree = tempfile::tempdir()?;
    let outside = tempfile::tempdir()?;
    let secret = outside.path().join("secret.txt");
    fs::write(&secret, "private key")?;
    symlink(&secret, worktree.path().join(AGENTS_FILE_NAME))?;

    let written = write_agents_file(worktree.path(), RULES);

    assert!(matches!(written, Err(AgentsFileError::NotPlainFile(_))));
    assert_eq!(fs::read_to_string(&secret)?, "private key");
    Ok(())
}

#[test]
fn creates_no_file_when_no_rule_applies() -> TestResult<()> {
    let worktree = tempfile::tempdir()?;

    write_agents_file(worktree.path(), "")?;

    assert!(!worktree.path().join(AGENTS_FILE_NAME).exists());
    Ok(())
}

proptest! {
    #[test]
    fn test_merge_agents_markdown_property_keeps_project_text_first(
        project in any_project_markdown(),
        rules in any_rules(),
    ) {
        let merged = merge_agents_markdown(&project, &rules);

        prop_assert!(merged.starts_with(&project));
        prop_assert!(merged.ends_with(&rules));
        if !project.is_empty() {
            let rules_after_blank_line = format!("\n\n{rules}");
            prop_assert!(merged.ends_with(&rules_after_blank_line));
        }
    }

    #[test]
    fn test_merge_agents_markdown_property_adds_the_rules_only_once(
        project in any_project_markdown(),
        rules in any_rules(),
    ) {
        let merged_once = merge_agents_markdown(&project, &rules);

        let merged_twice = merge_agents_markdown(&merged_once, &rules);

        prop_assert_eq!(merged_twice, merged_once);
    }

    #[test]
    fn test_merge_agents_markdown_property_never_panics_on_any_text(
        project in any::<String>(),
        rules in any::<String>(),
    ) {
        let merged = merge_agents_markdown(&project, &rules);

        prop_assert!(merged.starts_with(&project));
        prop_assert!(merged.ends_with(&rules));
    }

    #[test]
    fn test_write_agents_file_property_writes_the_merged_file_once(
        project in option::of(any_project_markdown()),
        rules in any_rules(),
    ) {
        let worktree = tempfile::tempdir().map_err(to_case_error)?;
        let path = worktree.path().join(AGENTS_FILE_NAME);
        if let Some(project) = &project {
            fs::write(&path, project).map_err(to_case_error)?;
        }

        write_agents_file(worktree.path(), &rules).map_err(to_case_error)?;
        write_agents_file(worktree.path(), &rules).map_err(to_case_error)?;

        let written = fs::read_to_string(&path).map_err(to_case_error)?;
        let project_text = project.unwrap_or_default();
        prop_assert_eq!(written, merge_agents_markdown(&project_text, &rules));
    }
}
