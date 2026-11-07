use chrono::{DateTime, TimeDelta, Utc};
use orchestration_api::work::TaskStart;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::ProjectId;
use orchestration_core::run::Run;
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_core::schedule_rules::next_run_after;
use orchestration_core::task::{Schedule, TimeOfDay};
use orchestration_server::{StoredState, find_due_jobs, start_due_jobs};
use proptest::prelude::*;
use uuid::Uuid;

use crate::deletion_fixtures::cancel_run;
use crate::fixtures::{
    create_account, create_project, one_agent_task, save_task,
};
use crate::test_client::{START_TIME_SECONDS, TestServer, block_on};

const MINUTES_PER_HOUR: u32 = 60;
const HOURS_PER_DAY: u32 = 24;

fn schedule_strategy() -> impl Strategy<Value = Schedule> {
    prop_oneof![
        (0..MINUTES_PER_HOUR).prop_map(|minute| Schedule::Hour { minute }),
        (0..HOURS_PER_DAY, 0..MINUTES_PER_HOUR).prop_map(|(hour, minute)| {
            Schedule::Day {
                at: TimeOfDay { hour, minute },
            }
        }),
    ]
}

fn start_time() -> DateTime<Utc> {
    DateTime::from_timestamp(START_TIME_SECONDS, 0).expect("valid start")
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(64))]

    #[test]
    fn test_find_due_jobs_property_due_exactly_when_next_run_passed(
        schedule in schedule_strategy(),
        elapsed_minutes in 0_i64..3_000,
    ) {
        let job = one_agent_task(
            ProjectId(Uuid::new_v4()),
            RunnerTarget::AnyFreeRunner,
            Some(schedule),
        );
        let mut state = StoredState::default();
        state.tasks.insert(job.id, job.clone());
        let now = start_time() + TimeDelta::minutes(elapsed_minutes);
        let next_run = next_run_after(&schedule, job.created_at)
            .expect("the schedule is valid");

        let due_jobs = find_due_jobs(&state, now);

        prop_assert_eq!(due_jobs.contains(&job.id), next_run <= now);
    }

    #[test]
    fn test_find_due_jobs_property_ignores_tasks_without_schedule(
        elapsed_minutes in 0_i64..3_000,
    ) {
        let task = one_agent_task(
            ProjectId(Uuid::new_v4()),
            RunnerTarget::AnyFreeRunner,
            None,
        );
        let mut state = StoredState::default();
        state.tasks.insert(task.id, task);
        let now = start_time() + TimeDelta::minutes(elapsed_minutes);

        prop_assert_eq!(find_due_jobs(&state, now).len(), 0);
    }
}

#[test]
fn the_scheduler_starts_one_run_each_time_a_job_is_due() {
    let test = TestServer::start();
    let run_counts = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let schedule = Schedule::Hour { minute: 0 };
        let job = one_agent_task(
            project.id,
            RunnerTarget::AnyFreeRunner,
            Some(schedule),
        );
        save_task(&test, &account, job, TaskStart::Later).await;
        let mut run_counts = Vec::new();
        for advance_minutes in [0, 61, 1, 60] {
            test.clock.advance(TimeDelta::minutes(advance_minutes));
            start_due_jobs(&test.server)
                .expect("the scheduler saves its runs");
            let runs: Vec<Run> =
                test.get(&account.owner, "/runs").await.json();
            run_counts.push(runs.len());
            for run in &runs {
                if !is_run_finished(run.status) {
                    cancel_run(&test, &account, run).await;
                }
            }
        }
        run_counts
    });

    assert_eq!(run_counts, [0, 1, 1, 2]);
}
