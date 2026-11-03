use std::fs;
use std::sync::Arc;

use orchestration_core::library::Rule;
use orchestration_core::workspace::AgentAccess;
use orchestration_hub::worktree_plan::plan_worktree;
use orchestration_runner::agents_file::AGENTS_FILE_NAME;
use orchestration_runner::run_executor::RunOutcome;
use orchestration_runner::worktree_request::describe_worktree_request;
use proptest::collection::vec;
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, claude_task, rule_titled};
use crate::executor_support::{RUN_NUMBER, execute_with_git_pusher};
use crate::fake_agent::{local_configuration, prepare_agent_folders};
use crate::fake_server::FakeServer;
use crate::git_support::{create_bare_origin, repository_at};
use crate::support::{TestResult, to_case_error};

const RULE_REMOVAL_CASES: u32 = 4;
const PROJECT_NOTES: &str = "# Project\nUse pnpm.\n";
const FIRST_RULE_NUMBER: u128 = 0x300;

struct RetryReport {
    outcomes: Vec<RunOutcome>,
    agents_file: Option<String>,
}

fn numbered_rules(count: usize) -> TestResult<Vec<Rule>> {
    let mut rules = Vec::new();
    for position in 0..count {
        let number = FIRST_RULE_NUMBER + u128::try_from(position)?;
        let title = format!("Rule number {position}");
        rules.push(rule_titled(number, &title, true));
    }
    Ok(rules)
}

fn run_then_retry_with(
    has_project_notes: bool,
    first_rules: Vec<Rule>,
    retried_rules: Vec<Rule>,
) -> TestResult<RetryReport> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let project_files: Vec<(&str, &str)> = if has_project_notes {
        vec![(AGENTS_FILE_NAME, PROJECT_NOTES)]
    } else {
        vec![("README.md", "hello")]
    };
    let origin =
        create_bare_origin(folders.temporary.path(), "app", &project_files)?;
    let repository = repository_at(&origin, AgentAccess::PushAfterApproval);
    let task = claude_task(RUN_NUMBER, "fix-it");
    let mut assignment =
        assignment_for(task, None, vec![repository], RUN_NUMBER)?;
    let request = describe_worktree_request(
        &assignment,
        &configuration.worktree_roots,
        &configuration.clone_source,
    );
    let plan = plan_worktree(&request)?;
    let worktree = plan.repositories.first().ok_or("no worktree")?;
    let agents_path = worktree.worktree.join(AGENTS_FILE_NAME);
    let server = Arc::new(FakeServer::with_queue(Vec::new()));
    let runtime = Runtime::new()?;

    assignment.rules = first_rules;
    let first = runtime.block_on(execute_with_git_pusher(
        &server,
        &configuration,
        assignment.clone(),
    ))?;
    assignment.rules = retried_rules;
    let retried = runtime.block_on(execute_with_git_pusher(
        &server,
        &configuration,
        assignment,
    ))?;

    let agents_file = if agents_path.exists() {
        Some(fs::read_to_string(agents_path)?)
    } else {
        None
    };
    Ok(RetryReport {
        outcomes: vec![first, retried],
        agents_file,
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RULE_REMOVAL_CASES))]

    #[test]
    fn test_execute_property_a_retry_writes_only_the_rules_that_remain(
        removed_flags in vec(any::<bool>(), 1..4),
        has_project_notes in any::<bool>(),
    ) {
        let rules =
            numbered_rules(removed_flags.len()).map_err(to_case_error)?;
        let mut remaining_rules = Vec::new();
        let mut removed_rules = Vec::new();
        for (rule, is_removed) in rules.iter().zip(&removed_flags) {
            if *is_removed {
                removed_rules.push(rule.clone());
            } else {
                remaining_rules.push(rule.clone());
            }
        }

        let report = run_then_retry_with(
            has_project_notes,
            rules,
            remaining_rules.clone(),
        )
        .map_err(to_case_error)?;

        prop_assert_eq!(
            report.outcomes,
            vec![RunOutcome::Finished, RunOutcome::Finished]
        );
        let is_file_expected =
            has_project_notes || !remaining_rules.is_empty();
        prop_assert_eq!(report.agents_file.is_some(), is_file_expected);
        let written = report.agents_file.unwrap_or_default();
        prop_assert_eq!(written.starts_with(PROJECT_NOTES), has_project_notes);
        for rule in &remaining_rules {
            prop_assert_eq!(written.matches(&rule.title).count(), 1);
        }
        for rule in &removed_rules {
            prop_assert!(!written.contains(&rule.title));
        }
    }
}
