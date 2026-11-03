use orchestration_core::run::{RunStatus, StepStatus};
use orchestration_core::workflow::StepKind;
use proptest::prelude::*;

use crate::branching_fixtures::{
    branching_workflow, claim_and_finish, claim_step, find_step, read_run,
    start_branching_run,
};
use crate::test_client::{TestServer, block_on};

const RUNNER_SLOTS: u32 = 16;
const OUTCOMES: [&str; 2] = ["approved", "changes"];

fn review_workflow(
    round_limit: u32,
) -> orchestration_core::workflow::Workflow {
    branching_workflow(
        &[
            ("draft", StepKind::Agent),
            ("review", StepKind::Agent),
            ("ship", StepKind::Agent),
        ],
        &[
            (0, 1, None, None),
            (1, 2, Some("approved"), None),
            (1, 0, Some("changes"), Some(round_limit)),
        ],
    )
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(6))]

    #[test]
    fn test_post_run_events_property_a_fork_takes_only_the_matching_branch(
        chosen in 0_usize..2,
    ) {
        let test = TestServer::start();
        let workflow = branching_workflow(
            &[
                ("review", StepKind::Agent),
                ("ship", StepKind::Agent),
                ("fix", StepKind::Agent),
            ],
            &[(0, 1, Some("approved"), None), (0, 2, Some("changes"), None)],
        );
        let (taken, skipped) = if chosen == 0 {
            ("ship", "fix")
        } else {
            ("fix", "ship")
        };

        let run = block_on(async {
            let started =
                start_branching_run(&test, workflow, 1, RUNNER_SLOTS).await;
            let runner = &started.runners[0];
            let outcome = Some(OUTCOMES[chosen]);
            claim_and_finish(&test, runner, "review", outcome).await;
            claim_and_finish(&test, runner, taken, None).await;
            let leftover = claim_step(&test, runner).await;
            assert!(leftover.is_none());
            read_run(&test, &started.account, &started.run).await
        });

        prop_assert_eq!(find_step(&run, skipped).status, StepStatus::Skipped);
        prop_assert_eq!(find_step(&run, taken).status, StepStatus::Done);
        prop_assert_eq!(run.status, RunStatus::Done);
    }

    #[test]
    fn test_post_run_events_property_a_join_waits_only_for_taken_branches(
        takes_left in any::<bool>(),
    ) {
        let test = TestServer::start();
        let workflow = branching_workflow(
            &[
                ("split", StepKind::Agent),
                ("left", StepKind::Agent),
                ("right", StepKind::Agent),
                ("join", StepKind::Agent),
            ],
            &[
                (0, 1, Some("left"), None),
                (0, 2, Some("right"), None),
                (1, 3, None, None),
                (2, 3, None, None),
            ],
        );
        let taken = if takes_left { "left" } else { "right" };

        let run = block_on(async {
            let started =
                start_branching_run(&test, workflow, 1, RUNNER_SLOTS).await;
            let runner = &started.runners[0];
            claim_and_finish(&test, runner, "split", Some(taken)).await;
            claim_and_finish(&test, runner, taken, None).await;
            claim_and_finish(&test, runner, "join", None).await;
            read_run(&test, &started.account, &started.run).await
        });

        prop_assert_eq!(run.status, RunStatus::Done);
        prop_assert_eq!(find_step(&run, "join").status, StepStatus::Done);
    }

    #[test]
    fn test_post_run_events_property_a_loop_reruns_until_its_limit(
        round_limit in 1_u32..=3,
    ) {
        let test = TestServer::start();

        let (run, carried) = block_on(async {
            let started =
                start_branching_run(
                    &test,
                    review_workflow(round_limit),
                    1,
                    RUNNER_SLOTS,
                )
                    .await;
            let runner = &started.runners[0];
            let mut carried = Vec::new();
            claim_and_finish(&test, runner, "draft", None).await;
            for _round in 0..round_limit {
                let changes = Some("changes");
                claim_and_finish(&test, runner, "review", changes).await;
                let redraft =
                    claim_and_finish(&test, runner, "draft", None).await;
                let draft = find_step(&redraft.run, "draft").clone();
                let review = find_step(&redraft.run, "review").clone();
                carried.push((draft.loop_source, review.earlier_rounds));
            }
            claim_and_finish(&test, runner, "review", Some("changes")).await;
            let leftover = claim_step(&test, runner).await;
            assert!(leftover.is_none());
            (read_run(&test, &started.account, &started.run).await, carried)
        });

        for (loop_source, earlier_review_rounds) in &carried {
            prop_assert_eq!(loop_source.as_deref(), Some("review"));
            let last_result = earlier_review_rounds
                .last()
                .and_then(|round| round.result.as_deref());
            prop_assert_eq!(last_result, Some("result of review"));
        }
        prop_assert_eq!(run.status, RunStatus::Done);
        prop_assert_eq!(find_step(&run, "ship").status, StepStatus::Skipped);
        let draft_rounds = find_step(&run, "draft").earlier_rounds.len();
        prop_assert_eq!(draft_rounds, usize::try_from(round_limit)?);
        prop_assert_eq!(run.loop_rounds[0].rounds, round_limit);
        let limit_note =
            format!(
                "review → draft reached its limit of {round_limit} rounds"
            );
        prop_assert_eq!(&run.notes[0].text, &limit_note);
        prop_assert_eq!(
            &run.notes[1].text,
            "Nothing else follows review, so the run finished"
        );
    }
}

#[test]
fn a_step_with_outcomes_cannot_finish_without_one() {
    let test = TestServer::start();

    let refused = block_on(async {
        let started =
            start_branching_run(&test, review_workflow(1), 1, RUNNER_SLOTS)
                .await;
        let runner = &started.runners[0];
        claim_and_finish(&test, runner, "draft", None).await;
        let review = claim_step(&test, runner).await.expect("review is ready");
        crate::branching_fixtures::finish_claimed_step(
            &test, runner, &review, None,
        )
        .await
    });

    assert_eq!(refused.status, axum::http::StatusCode::UNPROCESSABLE_ENTITY);
    assert!(
        refused
            .error_message()
            .contains("one of the outcomes: approved, changes"),
        "{}",
        refused.error_message()
    );
}
