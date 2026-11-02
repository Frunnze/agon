use std::collections::BTreeSet;

use orchestration_api::work::RunAssignment;
use orchestration_core::device::{DeviceRole, RunnerTarget};
use proptest::prelude::*;

use crate::claim_fixtures::{
    FIRST_RUNNER_SEED, claim, pair_runners, queue_runs,
};
use crate::fixtures::{
    create_account, create_project, heartbeat_with, identity_from_seed,
    pair_device, send_heartbeat,
};
use crate::test_client::{TestServer, block_on};

const LABEL_CHOICES: [&str; 3] = ["mac", "gpu", "arm64"];

fn choose_labels(mask: u8) -> Vec<&'static str> {
    LABEL_CHOICES
        .iter()
        .enumerate()
        .filter(|(position, _label)| mask & (1 << position) != 0)
        .map(|(_position, label)| *label)
        .collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_claim_next_run_property_gives_each_run_to_one_runner_at_most(
        runner_count in 1_u8..4,
        run_count in 1_usize..5,
        claim_order in proptest::collection::vec(0_usize..4, 0..24),
    ) {
        let test = TestServer::start();
        let assignments: Vec<RunAssignment> = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let runners =
                pair_runners(&test, &account, runner_count, 8).await;
            queue_runs(
                &test,
                &account,
                project.id,
                &RunnerTarget::AnyFreeRunner,
                run_count,
            )
            .await;
            let mut assignments = Vec::new();
            for runner_position in claim_order {
                let runner = &runners[runner_position % runners.len()];
                let response = claim(&test, runner).await;
                assignments.extend(response.assignment);
            }
            assignments
        });

        let mut claimed_runs = BTreeSet::new();
        for assignment in &assignments {
            prop_assert!(claimed_runs.insert(assignment.run.id));
            prop_assert_eq!(assignment.run.steps.len(), 1);
            prop_assert!(assignment.run.steps[0].runner.is_some());
        }
        prop_assert!(claimed_runs.len() <= run_count);
    }

    #[test]
    fn test_claim_next_run_property_respects_labels_and_free_slots(
        runner_mask in 0_u8..8,
        task_mask in 0_u8..8,
        slots_total in 0_u32..3,
        slots_busy_seed in 0_u32..3,
    ) {
        let slots_busy = slots_busy_seed.min(slots_total);
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let runner = identity_from_seed(FIRST_RUNNER_SEED);
            let role = DeviceRole::Runner;
            pair_device(&test, &account, &runner, "gpu-box", role).await;
            let heartbeat = heartbeat_with(
                &choose_labels(runner_mask),
                slots_total,
                slots_busy,
            );
            send_heartbeat(&test, &runner, &heartbeat).await;
            let required_labels: Vec<String> = choose_labels(task_mask)
                .iter()
                .map(|label| (*label).to_owned())
                .collect();
            let target = RunnerTarget::RunnerWithLabels {
                labels: required_labels,
            };
            queue_runs(&test, &account, project.id, &target, 1).await;
            claim(&test, &runner).await
        });

        let has_labels = task_mask & runner_mask == task_mask;
        let has_free_slot = slots_total > slots_busy;
        prop_assert_eq!(
            response.assignment.is_some(),
            has_labels && has_free_slot
        );
    }

    #[test]
    fn test_claim_next_run_property_never_exceeds_free_slots(
        slots_total in 1_u32..4,
        run_count in 1_usize..6,
    ) {
        let test = TestServer::start();
        let claimed_count = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let runners = pair_runners(&test, &account, 1, slots_total).await;
            queue_runs(
                &test,
                &account,
                project.id,
                &RunnerTarget::AnyFreeRunner,
                run_count,
            )
            .await;
            let mut claimed_count = 0_usize;
            for _attempt in 0..run_count {
                let response = claim(&test, &runners[0]).await;
                claimed_count += usize::from(response.assignment.is_some());
            }
            claimed_count
        });

        let slot_count =
            usize::try_from(slots_total).expect("slot count fits");
        prop_assert_eq!(claimed_count, run_count.min(slot_count));
    }
}
