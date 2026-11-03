use std::collections::BTreeSet;

use orchestration_core::run::RunStatus;
use orchestration_core::workflow::{StepKind, Workflow};
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::branching_fixtures::{
    PlannedConnection, branching_workflow, claim_and_finish, claim_step,
    finish_claimed_step, read_run, start_branching_run,
};
use crate::fixtures::{heartbeat_with, send_heartbeat};
use crate::test_client::{TestServer, block_on};

const REVIEWER_COUNT: usize = 5;
const REVIEWER_NAMES: [&str; REVIEWER_COUNT] = [
    "defects",
    "requirements",
    "property-a",
    "property-b",
    "fuzz",
];

fn review_row_workflow() -> Workflow {
    let mut steps = vec![("implement", StepKind::Agent)];
    for name in REVIEWER_NAMES {
        steps.push((name, StepKind::Agent));
    }
    steps.push(("ship", StepKind::Agent));
    let ship_index = REVIEWER_COUNT + 1;
    let mut connections: Vec<PlannedConnection<'_>> = Vec::new();
    for reviewer_index in 1..=REVIEWER_COUNT {
        connections.push((0, reviewer_index, None, None));
        connections.push((reviewer_index, ship_index, None, None));
    }
    branching_workflow(&steps, &connections)
}

async fn free_every_slot(
    test: &TestServer,
    runners: &[&DeviceIdentity],
    slots_per_runner: u32,
) {
    for runner in runners {
        let heartbeat = heartbeat_with(&[], slots_per_runner, 0);
        send_heartbeat(test, runner, &heartbeat).await;
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_claim_next_run_property_fans_ready_steps_out_at_once(
        runner_count in prop_oneof![Just(1_u8), Just(5_u8)],
    ) {
        let test = TestServer::start();
        let slots_per_runner = if runner_count == 1 { 5 } else { 1 };

        let (claimed_names, ship_before_join, run) = block_on(async {
            let started = start_branching_run(
                &test,
                review_row_workflow(),
                runner_count,
                slots_per_runner,
            )
            .await;
            let mut runners: Vec<&DeviceIdentity> =
                started.runners.iter().collect();
            runners.sort_by_key(|runner| runner.device_id());
            claim_and_finish(&test, runners[0], "implement", None).await;
            free_every_slot(&test, &runners, slots_per_runner).await;
            let mut claimed = Vec::new();
            for round in 0..REVIEWER_COUNT {
                let runner_index = round % runners.len();
                let runner = runners[runner_index];
                let assignment = claim_step(&test, runner).await;
                let assignment = assignment.expect("a reviewer is ready");
                claimed.push((runner_index, assignment));
            }
            let (last_index, last_review) =
                claimed.pop().expect("five reviewers are claimed");
            for (runner_index, assignment) in &claimed {
                let runner = runners[*runner_index];
                finish_claimed_step(&test, runner, assignment, None).await;
            }
            free_every_slot(&test, &runners, slots_per_runner).await;
            let ship_before_join = claim_step(&test, runners[0]).await;
            let last_runner = runners[last_index];
            finish_claimed_step(&test, last_runner, &last_review, None).await;
            claim_and_finish(&test, runners[0], "ship", None).await;
            claimed.push((last_index, last_review));
            let names: BTreeSet<String> = claimed
                .iter()
                .map(|(_, assignment)| assignment.step_name.clone())
                .collect();
            let run = read_run(&test, &started.account, &started.run).await;
            (names, ship_before_join.is_some(), run)
        });

        let expected: BTreeSet<String> =
            REVIEWER_NAMES.iter().map(|name| (*name).to_owned()).collect();
        prop_assert_eq!(claimed_names, expected);
        prop_assert!(!ship_before_join);
        prop_assert_eq!(run.status, RunStatus::Done);
    }
}
