use chrono::TimeDelta;
use orchestration_api::updates::AuditView;
use orchestration_core::identifiers::RunId;
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_server::{find_due_jobs, start_due_jobs};
use proptest::prelude::*;

use crate::active_run_desk::{
    ActiveRunDesk, WorkKind, count_active_runs, open_desk,
};
use crate::test_client::block_on;

const SCHEDULE_CASES: u32 = 16;
const ADVANCE_MINUTES_LIMIT: i64 = 150;
const JOB_ACTION_LIMIT: usize = 9;

#[derive(Clone, Copy, Debug)]
enum JobAction {
    Advance { minutes: i64 },
    CancelActive,
}

#[derive(Debug)]
struct ObservedPass {
    was_due: bool,
    active_before: usize,
    started_runs: Vec<RunId>,
    active_after: usize,
    last_audit_event: String,
    is_due_after: bool,
}

fn job_actions_strategy() -> impl Strategy<Value = Vec<JobAction>> {
    let action = prop_oneof![
        (0..ADVANCE_MINUTES_LIMIT)
            .prop_map(|minutes| JobAction::Advance { minutes }),
        Just(JobAction::CancelActive),
    ];
    proptest::collection::vec(action, 1..JOB_ACTION_LIMIT)
}

fn is_job_due(desk: &ActiveRunDesk) -> bool {
    let now = desk.test.now();
    let due_jobs = desk
        .test
        .server
        .read(|state| Ok(find_due_jobs(state, now)))
        .expect("the state is readable");
    due_jobs.contains(&desk.task.id)
}

async fn read_last_audit_event(desk: &ActiveRunDesk) -> String {
    let audit: AuditView =
        desk.test.get(&desk.account.owner, "/audit").await.json();
    audit
        .entries
        .last()
        .map(|entry| entry.event.clone())
        .unwrap_or_default()
}

async fn cancel_active_run(desk: &ActiveRunDesk) {
    let runs = desk.list_runs().await;
    let active_run = runs.iter().find(|run| !is_run_finished(run.status));
    if let Some(active_run) = active_run {
        desk.cancel(active_run).await;
    }
}

async fn run_scheduler_pass(desk: &ActiveRunDesk) -> ObservedPass {
    let was_due = is_job_due(desk);
    let active_before = count_active_runs(&desk.list_runs().await);
    let started_runs =
        start_due_jobs(&desk.test.server).expect("the scheduler saves");
    let active_after = count_active_runs(&desk.list_runs().await);
    ObservedPass {
        was_due,
        active_before,
        started_runs,
        active_after,
        last_audit_event: read_last_audit_event(desk).await,
        is_due_after: is_job_due(desk),
    }
}

fn observe_schedule(
    desk: &ActiveRunDesk,
    actions: &[JobAction],
) -> Vec<ObservedPass> {
    block_on(async {
        let mut passes = Vec::new();
        for action in actions {
            match action {
                JobAction::Advance { minutes } => {
                    desk.test.clock.advance(TimeDelta::minutes(*minutes));
                }
                JobAction::CancelActive => cancel_active_run(desk).await,
            }
            passes.push(run_scheduler_pass(desk).await);
        }
        passes
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SCHEDULE_CASES))]

    #[test]
    fn test_start_due_jobs_property_never_starts_a_second_active_run(
        actions in job_actions_strategy(),
    ) {
        let desk = open_desk(WorkKind::Job.schedule());

        let passes = observe_schedule(&desk, &actions);

        for pass in &passes {
            prop_assert!(pass.active_after <= 1, "{:?}", pass);
        }
    }

    #[test]
    fn test_start_due_jobs_property_starts_exactly_when_due_and_idle(
        actions in job_actions_strategy(),
    ) {
        let desk = open_desk(WorkKind::Job.schedule());

        let passes = observe_schedule(&desk, &actions);

        for pass in &passes {
            let should_start = pass.was_due && pass.active_before == 0;
            prop_assert_eq!(!pass.started_runs.is_empty(), should_start);
            prop_assert!(!pass.is_due_after, "{:?}", pass);
        }
    }

    #[test]
    fn test_start_due_jobs_property_a_busy_due_job_is_skipped_with_a_note(
        actions in job_actions_strategy(),
    ) {
        let desk = open_desk(WorkKind::Job.schedule());
        let skipped_note = format!(
            "Could not start job {}: {}",
            desk.task.title,
            WorkKind::Job.already_running_message()
        );

        let passes = observe_schedule(&desk, &actions);

        for pass in &passes {
            let is_skipped = pass.was_due && pass.active_before == 1;
            if is_skipped {
                prop_assert_eq!(&pass.last_audit_event, &skipped_note);
                prop_assert_eq!(pass.active_after, 1);
            }
        }
    }
}
