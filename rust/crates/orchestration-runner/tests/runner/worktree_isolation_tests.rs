use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::RunId;
use orchestration_core::run::StepStatus;
use orchestration_core::workspace::AgentAccess;
use orchestration_runner::run_executor::RunOutcome;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::event_queries::branches;
use crate::fake_agent::{
    AgentFolders, prepare_agent_folders, read_working_folders,
};
use crate::git_support::{create_bare_origin, repository_at, run_git};
use crate::mix_execution::{
    AttemptRecord, MixExecution, count_attempts, execute_mix,
};
use crate::run_mixes::{MixedRun, any_run_mix, build_mixed_runs};
use crate::support::{TestResult, to_case_error};

const REPOSITORY_NAME: &str = "app";
const MAXIMUM_RUNS_WITH_REPOSITORY: usize = 6;
const MAXIMUM_RUNS_WITHOUT_REPOSITORY: usize = 8;
const FAILING_DETAILS: &str = "please-fail";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Milestone {
    WorktreeCreated,
    StepRunning,
}

#[derive(Debug)]
struct ObservedAttempt<'execution> {
    record: &'execution AttemptRecord,
    working_folder: PathBuf,
    posted_branch: String,
    checked_out_branch: String,
}

fn observe_attempts<'execution>(
    folders: &AgentFolders,
    execution: &'execution MixExecution,
) -> TestResult<Vec<ObservedAttempt<'execution>>> {
    let working_folders = read_working_folders(folders)?;
    if working_folders.len() != execution.attempts.len() {
        return Err("the agent did not start once per attempt".into());
    }

    let mut observed = Vec::new();
    for (record, working_folder) in
        execution.attempts.iter().zip(working_folders)
    {
        let events = execution.server.events_of(record.run_id);
        let posted_branches = branches(&events);
        let posted_branch = posted_branches
            .get(record.attempt_number)
            .ok_or("the attempt posted no worktree branch")?;
        let worktree = working_folder.join(REPOSITORY_NAME);
        let checked_out_branch =
            run_git(&worktree, &["rev-parse", "--abbrev-ref", "HEAD"])?;
        observed.push(ObservedAttempt {
            record,
            posted_branch: posted_branch.clone(),
            working_folder,
            checked_out_branch,
        });
    }
    Ok(observed)
}

fn is_inside_another_run_folder(
    attempt: &ObservedAttempt,
    run_folders: &BTreeSet<&Path>,
) -> bool {
    let own_folder = attempt.record.task_folder.as_path();
    run_folders.iter().any(|run_folder| {
        *run_folder != own_folder
            && attempt.working_folder.starts_with(run_folder)
    })
}

fn group_by_run<'attempts, 'execution>(
    observed: &'attempts [ObservedAttempt<'execution>],
) -> BTreeMap<RunId, Vec<&'attempts ObservedAttempt<'execution>>> {
    let mut grouped: BTreeMap<RunId, Vec<&ObservedAttempt>> = BTreeMap::new();
    for attempt in observed {
        let run_attempts = grouped.entry(attempt.record.run_id).or_default();
        run_attempts.push(attempt);
    }
    grouped
}

fn check_attempt_stays_in_its_folder(
    attempt: &ObservedAttempt,
    run_folders: &BTreeSet<&Path>,
    cache_root: &Path,
) -> Result<(), TestCaseError> {
    let working_folder = &attempt.working_folder;
    let own_folder = &attempt.record.task_folder;
    prop_assert_eq!(attempt.record.outcome, RunOutcome::Finished);
    prop_assert!(working_folder.starts_with(own_folder));
    prop_assert!(!working_folder.starts_with(cache_root));
    prop_assert!(!is_inside_another_run_folder(attempt, run_folders));
    prop_assert_eq!(&attempt.checked_out_branch, &attempt.posted_branch);
    Ok(())
}

fn check_retries_reuse_their_folder(
    observed: &[ObservedAttempt],
) -> Result<(), TestCaseError> {
    for run_attempts in group_by_run(observed).values() {
        let first = run_attempts
            .first()
            .ok_or_else(|| to_case_error("a run has no attempt"))?;
        for attempt in run_attempts {
            let is_retry = attempt.record.attempt_number > 0;
            prop_assert_eq!(attempt.record.was_folder_present, is_retry);
            prop_assert_eq!(
                &attempt.record.task_folder,
                &first.record.task_folder
            );
            prop_assert_eq!(&attempt.posted_branch, &first.posted_branch);
        }
    }
    Ok(())
}

fn fail_chosen_agents(
    mixed_runs: Vec<MixedRun>,
    failing_runs: &[bool],
) -> Vec<MixedRun> {
    let mut adjusted_runs = Vec::new();
    for (mut mixed_run, is_failing) in mixed_runs.into_iter().zip(failing_runs)
    {
        if *is_failing {
            mixed_run.assignment.task.details = FAILING_DETAILS.to_string();
        }
        adjusted_runs.push(mixed_run);
    }
    adjusted_runs
}

fn list_milestones(events: &[RunEvent]) -> Vec<Milestone> {
    let mut milestones = Vec::new();
    for event in events {
        match event {
            RunEvent::WorktreeCreated { .. } => {
                milestones.push(Milestone::WorktreeCreated);
            }
            RunEvent::StepStatusChanged {
                status: StepStatus::Running,
                ..
            } => milestones.push(Milestone::StepRunning),
            _ => {}
        }
    }
    milestones
}

fn expected_milestones(attempt_count: usize) -> Vec<Milestone> {
    let mut milestones = Vec::new();
    for _attempt in 0..attempt_count {
        milestones.push(Milestone::WorktreeCreated);
        milestones.push(Milestone::StepRunning);
    }
    milestones
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_execute_property_every_run_works_in_its_own_worktree(
        mix in any_run_mix(MAXIMUM_RUNS_WITH_REPOSITORY),
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let temporary = folders.temporary.path();
        let origin = create_bare_origin(temporary, REPOSITORY_NAME, &[])
            .map_err(to_case_error)?;
        let repository = repository_at(&origin, AgentAccess::ReadOnly);
        let mixed_runs =
            build_mixed_runs(&mix, &[repository]).map_err(to_case_error)?;

        let execution =
            execute_mix(&folders, &mixed_runs).map_err(to_case_error)?;

        let observed =
            observe_attempts(&folders, &execution).map_err(to_case_error)?;
        let cache_root =
            folders.cache_root.canonicalize().map_err(to_case_error)?;
        let mut run_folders = BTreeSet::new();
        let mut run_branches = BTreeSet::new();
        for attempt in &observed {
            run_folders.insert(attempt.record.task_folder.as_path());
            run_branches.insert(attempt.posted_branch.as_str());
        }
        prop_assert_eq!(run_folders.len(), mixed_runs.len());
        prop_assert_eq!(run_branches.len(), mixed_runs.len());
        for attempt in &observed {
            check_attempt_stays_in_its_folder(
                attempt,
                &run_folders,
                &cache_root,
            )?;
        }
        check_retries_reuse_their_folder(&observed)?;
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_execute_property_worktree_is_announced_before_the_step_runs(
        mix in any_run_mix(MAXIMUM_RUNS_WITHOUT_REPOSITORY),
        failing_runs in vec(any::<bool>(), MAXIMUM_RUNS_WITHOUT_REPOSITORY),
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let mixed_runs =
            build_mixed_runs(&mix, &[]).map_err(to_case_error)?;
        let mixed_runs = fail_chosen_agents(mixed_runs, &failing_runs);

        let execution =
            execute_mix(&folders, &mixed_runs).map_err(to_case_error)?;

        for mixed_run in &mixed_runs {
            let run_id = mixed_run.assignment.run.id;
            let events = execution.server.events_of(run_id);
            let attempt_count = count_attempts(mixed_run);
            prop_assert_eq!(
                list_milestones(&events),
                expected_milestones(attempt_count)
            );
        }
    }
}
