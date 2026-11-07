use axum::http::StatusCode;
use proptest::prelude::*;

use crate::runner_slot_desk::{
    claim_counting_work, offer_busy_slots, open_slot_desk, read_slot_runner,
    report_busy_slots,
};
use crate::test_client::{TestServer, block_on};

const CASE_COUNT: u32 = 16;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_claim_next_run_property_busy_slots_never_exceed_total(
        slots_total in 0_u32..4,
        slots_busy_seed in 0_u32..4,
        run_count in 0_usize..6,
        claim_count in 0_usize..8,
    ) {
        let slots_busy = slots_busy_seed.min(slots_total);
        let test = TestServer::start();
        let busy_counts: Vec<u32> = block_on(async {
            let desk =
                open_slot_desk(&test, slots_total, slots_busy, run_count)
                    .await;
            let mut busy_counts = Vec::new();
            for _claim in 0..claim_count {
                claim_counting_work(&test, &desk).await;
                let runner = read_slot_runner(&test, &desk).await;
                busy_counts.push(runner.slots_busy);
            }
            busy_counts
        });

        for busy_count in busy_counts {
            prop_assert!(busy_count <= slots_total);
        }
    }

    #[test]
    fn test_claim_next_run_property_counts_one_busy_slot_per_claim(
        slots_total in 0_u32..4,
        slots_busy_seed in 0_u32..4,
        run_count in 0_usize..6,
        claim_count in 0_usize..8,
    ) {
        let slots_busy = slots_busy_seed.min(slots_total);
        let test = TestServer::start();
        let (claimed_count, final_busy) = block_on(async {
            let desk =
                open_slot_desk(&test, slots_total, slots_busy, run_count)
                    .await;
            let mut claimed_count = 0_u32;
            for _claim in 0..claim_count {
                claimed_count += claim_counting_work(&test, &desk).await;
            }
            let runner = read_slot_runner(&test, &desk).await;
            (claimed_count, runner.slots_busy)
        });

        let free_slots = slots_total - slots_busy;
        let run_limit = u32::try_from(run_count.min(claim_count))
            .expect("the run count fits");
        prop_assert_eq!(claimed_count, free_slots.min(run_limit));
        prop_assert_eq!(final_busy, slots_busy + claimed_count);
    }

    #[test]
    fn test_claim_next_run_property_full_runner_gets_no_work(
        slots_total in 0_u32..4,
        run_count in 1_usize..5,
        claim_count in 1_usize..5,
    ) {
        let test = TestServer::start();
        let (claimed_count, final_busy) = block_on(async {
            let desk =
                open_slot_desk(&test, slots_total, slots_total, run_count)
                    .await;
            let mut claimed_count = 0_u32;
            for _claim in 0..claim_count {
                claimed_count += claim_counting_work(&test, &desk).await;
            }
            let runner = read_slot_runner(&test, &desk).await;
            (claimed_count, runner.slots_busy)
        });

        prop_assert_eq!(claimed_count, 0);
        prop_assert_eq!(final_busy, slots_total);
    }

    #[test]
    fn test_claim_next_run_property_heartbeats_between_claims_stay_in_total(
        slots_total in 0_u32..4,
        steps in proptest::collection::vec(
            proptest::option::of(0_u32..5),
            0..10,
        ),
    ) {
        let test = TestServer::start();
        let busy_counts: Vec<u32> = block_on(async {
            let run_count = steps.len();
            let desk = open_slot_desk(&test, slots_total, 0, run_count).await;
            let mut busy_counts = Vec::new();
            for step in &steps {
                match step {
                    Some(busy_seed) => {
                        let reported_busy = busy_seed % (slots_total + 1);
                        let runner = &desk.runner;
                        report_busy_slots(
                            &test,
                            runner,
                            slots_total,
                            reported_busy,
                        )
                        .await;
                    }
                    None => {
                        claim_counting_work(&test, &desk).await;
                    }
                }
                let runner = read_slot_runner(&test, &desk).await;
                busy_counts.push(runner.slots_busy);
            }
            busy_counts
        });

        for busy_count in busy_counts {
            prop_assert!(busy_count <= slots_total);
        }
    }

    #[test]
    fn test_receive_heartbeat_property_rejects_more_busy_than_total(
        slots_total in 0_u32..4,
        extra_busy in 1_u32..4,
    ) {
        let test = TestServer::start();
        let (status, kept_busy) = block_on(async {
            let desk = open_slot_desk(&test, slots_total, 0, 0).await;
            let response = offer_busy_slots(
                &test,
                &desk.runner,
                slots_total,
                slots_total + extra_busy,
            )
            .await;
            let runner = read_slot_runner(&test, &desk).await;
            (response.status, runner.slots_busy)
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert_eq!(kept_busy, 0);
    }
}
