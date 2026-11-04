use std::fs;

use orchestration_core::run::StepStatus;
use orchestration_core::workspace::{AgentAccess, Repository};
use proptest::prelude::*;

use crate::event_queries::step_statuses;
use crate::fake_agent::{AgentFolders, prepare_agent_folders};
use crate::fan_out_runs::{
    FanOutRun, queue_reviewers, run_fan_out, statuses_of_step,
};
use crate::git_support::{create_bare_origin, repository_at};
use crate::support::{TestResult, to_case_error};

const FEWEST_SLOTS: usize = 2;
const MOST_SLOTS: usize = 4;
const REPOSITORY_NAME: &str = "app";
const GATHERED_FILE: &str = "gathered.txt";
const PROJECT_AGENTS_FILE: &str = "AGENTS.md";
const PROJECT_AGENTS_TEXT: &str = "Keep reviews short.\n";

fn project_repositories(
    folders: &AgentFolders,
    has_repository: bool,
) -> TestResult<Vec<Repository>> {
    if !has_repository {
        return Ok(Vec::new());
    }
    let root = folders.temporary.path();
    let project_files = [(PROJECT_AGENTS_FILE, PROJECT_AGENTS_TEXT)];
    let origin = create_bare_origin(root, REPOSITORY_NAME, &project_files)?;
    Ok(vec![repository_at(&origin, AgentAccess::ReadOnly)])
}

fn run_gathering_reviewers(
    slot_capacity: usize,
    has_repository: bool,
) -> TestResult<FanOutRun> {
    let folders = prepare_agent_folders()?;
    let repositories = project_repositories(&folders, has_repository)?;
    let gathering = format!("please-gather-{slot_capacity}");
    let instructions = vec![gathering; slot_capacity];
    let assignments = queue_reviewers(&instructions, repositories)?;
    run_fan_out(folders, assignments)
}

fn read_gathered_names(folders: &AgentFolders) -> TestResult<Vec<String>> {
    let gathered = fs::read_to_string(folders.records.join(GATHERED_FILE))?;
    let mut names: Vec<String> =
        gathered.lines().map(ToString::to_string).collect();
    names.sort();
    Ok(names)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(6))]

    #[test]
    fn test_run_runner_property_runs_the_ready_steps_of_a_run_at_once(
        slot_capacity in FEWEST_SLOTS..=MOST_SLOTS,
        has_repository in any::<bool>(),
    ) {
        let fan_out = run_gathering_reviewers(slot_capacity, has_repository)
            .map_err(to_case_error)?;

        let events = fan_out.server.events_of(fan_out.run_id);
        let statuses = step_statuses(&events);
        for reviewer_name in &fan_out.reviewer_names {
            prop_assert_eq!(
                statuses_of_step(&statuses, reviewer_name),
                vec![StepStatus::Running, StepStatus::Done],
                "{} in {:?}",
                reviewer_name,
                events
            );
        }
        let gathered =
            read_gathered_names(&fan_out.folders).map_err(to_case_error)?;
        prop_assert_eq!(gathered, fan_out.reviewer_names);
    }
}
