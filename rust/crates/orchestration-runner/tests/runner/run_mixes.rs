use orchestration_api::work::RunAssignment;
use orchestration_core::task::{Schedule, Task};
use orchestration_core::workspace::Repository;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::assignments::{assignment_for, claude_task};
use crate::support::TestResult;

const MIXED_TITLES: [&str; 2] = ["Fix the login bug", "Nightly cleanup"];
const JOB_COUNT: usize = 2;
const JOB_SCHEDULE: Schedule = Schedule::Hour { minute: 0 };
const JOB_TASK_NUMBER_BASE: u128 = 0x1000;
const ONE_OFF_TASK_NUMBER_BASE: u128 = 0x2000;
const RUN_ID_NUMBER_BASE: u128 = 0x3000;

#[derive(Clone, Copy, Debug)]
pub enum RunChoice {
    OneOffTask { title_index: usize },
    NextJobRun { job_index: usize },
}

#[derive(Clone, Copy, Debug)]
pub struct ChosenRun {
    pub choice: RunChoice,
    pub is_retried: bool,
}

#[derive(Clone, Debug)]
pub struct RunMix {
    pub job_title_indexes: Vec<usize>,
    pub runs: Vec<ChosenRun>,
}

#[derive(Clone, Debug)]
pub struct MixedRun {
    pub assignment: RunAssignment,
    pub is_retried: bool,
}

pub fn any_run_mix(maximum_runs: usize) -> impl Strategy<Value = RunMix> {
    let job_title_indexes = vec(any_title_index(), JOB_COUNT);
    let runs = vec(any_chosen_run(), 1..=maximum_runs);
    (job_title_indexes, runs).prop_map(|(job_title_indexes, runs)| RunMix {
        job_title_indexes,
        runs,
    })
}

pub fn build_mixed_runs(
    mix: &RunMix,
    repositories: &[Repository],
) -> TestResult<Vec<MixedRun>> {
    let mut started_job_runs = [0_u32; JOB_COUNT];
    let mut mixed_runs = Vec::new();
    for (position, chosen) in mix.runs.iter().enumerate() {
        let position_number = u128::try_from(position)?;
        let task = match chosen.choice {
            RunChoice::OneOffTask { title_index } => {
                let task_number = ONE_OFF_TASK_NUMBER_BASE + position_number;
                claude_task(task_number, title_at(title_index)?)
            }
            RunChoice::NextJobRun { job_index } => job_task(mix, job_index)?,
        };

        let run_id_number = RUN_ID_NUMBER_BASE + position_number;
        let mut assignment =
            assignment_for(task, None, repositories.to_vec(), run_id_number)?;
        if let RunChoice::NextJobRun { job_index } = chosen.choice {
            let started = started_job_runs
                .get_mut(job_index)
                .ok_or("the job index is out of range")?;
            *started += 1;
            assignment.run.number = *started;
        }

        mixed_runs.push(MixedRun {
            assignment,
            is_retried: chosen.is_retried,
        });
    }
    Ok(mixed_runs)
}

fn any_title_index() -> impl Strategy<Value = usize> {
    0..MIXED_TITLES.len()
}

fn any_chosen_run() -> impl Strategy<Value = ChosenRun> {
    let choice = prop_oneof![
        any_title_index().prop_map(one_off_task),
        (0..JOB_COUNT).prop_map(next_job_run),
    ];
    (choice, any::<bool>())
        .prop_map(|(choice, is_retried)| ChosenRun { choice, is_retried })
}

fn one_off_task(title_index: usize) -> RunChoice {
    RunChoice::OneOffTask { title_index }
}

fn next_job_run(job_index: usize) -> RunChoice {
    RunChoice::NextJobRun { job_index }
}

fn title_at(title_index: usize) -> TestResult<&'static str> {
    let title = MIXED_TITLES.get(title_index);
    Ok(title.ok_or("the title index is out of range")?)
}

fn job_task(mix: &RunMix, job_index: usize) -> TestResult<Task> {
    let title_index = mix
        .job_title_indexes
        .get(job_index)
        .ok_or("the job has no title")?;
    let task_number = JOB_TASK_NUMBER_BASE + u128::try_from(job_index)?;
    Ok(Task {
        schedule: Some(JOB_SCHEDULE),
        ..claude_task(task_number, title_at(*title_index)?)
    })
}
