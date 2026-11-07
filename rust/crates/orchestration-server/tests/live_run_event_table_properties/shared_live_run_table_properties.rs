use std::collections::BTreeSet;
use std::env;

use chrono::DateTime;
use orchestration_api::work::RunEvent;
use orchestration_core::run::RunStatus;
use orchestration_core::run_lifecycle::{
    derive_run_status, is_run_finished, is_step_finished,
};
use proptest::prelude::*;

use crate::live_run_event_plans::{CaseDice, PostedEvent, plan_case};
use crate::live_run_event_replay::replay_posted_events;
use crate::shared_live_run_table::{
    WRITE_TABLE_VARIABLE, adopt_table_identity, read_shared_table,
    write_shared_table,
};
use crate::test_client::{START_TIME_SECONDS, block_on};

const REACHABLE_STATUSES: [RunStatus; 5] = [
    RunStatus::Queued,
    RunStatus::Running,
    RunStatus::WaitingForApproval,
    RunStatus::Failed,
    RunStatus::Done,
];
const EVENT_KIND_COUNT: usize = 8;

fn name_event_kind(event: &RunEvent) -> &'static str {
    match event {
        RunEvent::StepStatusChanged { .. } => "step_status_changed",
        RunEvent::LogAppended { .. } => "log_appended",
        RunEvent::ChatAppended { .. } => "chat_appended",
        RunEvent::SessionStarted { .. } => "session_started",
        RunEvent::WorktreeCreated { .. } => "worktree_created",
        RunEvent::LinkChanged { .. } => "link_changed",
        RunEvent::Failed { .. } => "failed",
        RunEvent::StepResultRecorded { .. } => "step_result_recorded",
        RunEvent::Finished => "finished",
    }
}

#[test]
fn test_apply_run_event_property_shared_cases_match_the_server() {
    if env::var_os(WRITE_TABLE_VARIABLE).is_some() {
        write_shared_table();
    }

    for case in read_shared_table().cases {
        let posted_events: Vec<PostedEvent> = case
            .events
            .iter()
            .map(|shared_event| shared_event.posted.clone())
            .collect();
        let table_acceptances: Vec<bool> = case
            .events
            .iter()
            .map(|shared_event| shared_event.is_accepted)
            .collect();
        let replaying = replay_posted_events(&case.step_names, &posted_events);
        let replayed = block_on(replaying);

        let initial = &replayed.initial_run;
        let expected = &replayed.expected_run;
        assert_eq!(initial.steps.len(), case.initial_run.steps.len());
        assert_eq!(expected.steps.len(), case.expected_run.steps.len());
        let adopted_initial = adopt_table_identity(initial, &case.initial_run);
        let adopted_expected =
            adopt_table_identity(expected, &case.expected_run);
        assert_eq!(adopted_initial, case.initial_run);
        assert_eq!(replayed.acceptances, table_acceptances);
        assert_eq!(adopted_expected, case.expected_run, "{:?}", case.events);
    }
}

#[test]
fn test_apply_run_event_property_shared_cases_reach_every_run_status() {
    let table = read_shared_table();
    let reached: BTreeSet<String> = table
        .cases
        .iter()
        .map(|case| format!("{:?}", case.expected_run.status))
        .collect();

    for status in REACHABLE_STATUSES {
        assert!(reached.contains(&format!("{status:?}")), "{status:?}");
    }
}

#[test]
fn test_apply_run_event_property_shared_cases_post_every_kind_in_order() {
    let table = read_shared_table();
    let mut posted_kinds = BTreeSet::new();
    let mut acceptances = BTreeSet::new();

    for case in &table.cases {
        let mut previous = case.initial_run.started_at;
        for shared_event in &case.events {
            let posted = &shared_event.posted;
            assert!(posted.posted_at >= previous, "{:?}", case.events);
            previous = posted.posted_at;
            posted_kinds.insert(name_event_kind(&posted.event));
            acceptances.insert(shared_event.is_accepted);
        }
    }
    assert_eq!(posted_kinds.len(), EVENT_KIND_COUNT, "{posted_kinds:?}");
    assert_eq!(acceptances, BTreeSet::from([false, true]));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(12))]

    #[test]
    fn test_apply_run_event_property_status_follows_the_steps(
        seed in any::<u64>(),
    ) {
        let start = DateTime::from_timestamp(START_TIME_SECONDS, 0)
            .expect("the start time is valid");
        let planned = plan_case(&mut CaseDice::seeded(seed), start);

        let replaying =
            replay_posted_events(&planned.step_names, &planned.events);
        let replayed = block_on(replaying);

        let run = &replayed.expected_run;
        let is_finished = is_run_finished(run.status);
        prop_assert_eq!(run.status, derive_run_status(&run.steps));
        prop_assert_eq!(run.finished_at.is_some(), is_finished);
        if run.status == RunStatus::Failed {
            for step in &run.steps {
                prop_assert!(is_step_finished(step.status));
                prop_assert!(step.finished_at.is_some());
            }
        }
        for step in &run.steps {
            let is_finished = is_step_finished(step.status);
            prop_assert_eq!(step.finished_at.is_some(), is_finished);
        }
    }
}
