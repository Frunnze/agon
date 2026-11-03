use axum::http::StatusCode;
use orchestration_api::updates::ApiErrorBody;
use orchestration_api::work::OpenPersonStep;
use orchestration_core::run::{Run, RunStatus, StepStatus};
use orchestration_core::workflow::{StepKind, Workflow};
use proptest::prelude::*;

use crate::branching_fixtures::{
    BranchingRun, answer_step, branching_workflow, claim_and_finish,
    claim_step, find_step, read_run, start_branching_run,
};
use crate::fixtures::SEALED_DETAILS;
use crate::test_client::{TestServer, block_on};

const RUNNER_SLOTS: u32 = 2;
const PERSON_STEPS_PATH: &str = "/person-steps";

fn approval_workflow() -> Workflow {
    branching_workflow(
        &[
            ("draft", StepKind::Agent),
            ("approve", StepKind::Person),
            ("ship", StepKind::Agent),
        ],
        &[
            (0, 1, None, None),
            (1, 2, Some("approved"), None),
            (1, 0, Some("changes"), Some(1)),
        ],
    )
}

async fn reach_the_question(test: &TestServer) -> BranchingRun {
    let started =
        start_branching_run(test, approval_workflow(), 1, RUNNER_SLOTS).await;
    claim_and_finish(test, &started.runners[0], "draft", None).await;
    started
}

async fn list_open_steps(
    test: &TestServer,
    started: &BranchingRun,
) -> Vec<OpenPersonStep> {
    let response = test.get(&started.account.owner, PERSON_STEPS_PATH).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

#[test]
fn a_person_step_waits_and_is_never_claimed() {
    let test = TestServer::start();

    let (run, leftover, open_steps) = block_on(async {
        let started = reach_the_question(&test).await;
        let leftover = claim_step(&test, &started.runners[0]).await;
        let open_steps = list_open_steps(&test, &started).await;
        let run = read_run(&test, &started.account, &started.run).await;
        (run, leftover, open_steps)
    });

    assert!(leftover.is_none());
    assert_eq!(
        find_step(&run, "approve").status,
        StepStatus::WaitingForPerson
    );
    assert_eq!(run.status, RunStatus::Running);
    let [open_step] = open_steps.as_slice() else {
        panic!("one person step is open: {open_steps:?}");
    };
    assert_eq!(open_step.run_id, run.id);
    assert_eq!(open_step.step_name, "approve");
    assert_eq!(open_step.question, SEALED_DETAILS);
    assert_eq!(open_step.choices, vec!["approved", "changes"]);
    assert!(open_step.asked_at.is_some());
}

#[test]
fn a_runner_cannot_answer_a_person_step() {
    let test = TestServer::start();

    let status = block_on(async {
        let started = reach_the_question(&test).await;
        let runner = &started.runners[0];
        answer_step(&test, runner, &started.run, "approve", "approved")
            .await
            .status
    });

    assert_eq!(status, StatusCode::FORBIDDEN);
}

#[test]
fn an_answer_to_a_step_that_is_not_waiting_is_refused() {
    let test = TestServer::start();

    let status = block_on(async {
        let started =
            start_branching_run(&test, approval_workflow(), 1, RUNNER_SLOTS)
                .await;
        let owner = &started.account.owner;
        answer_step(&test, owner, &started.run, "approve", "approved")
            .await
            .status
    });

    assert_eq!(status, StatusCode::CONFLICT);
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_answer_person_step_property_refuses_answers_with_the_choices(
        answer in "[x-z]{1,8}",
    ) {
        let test = TestServer::start();

        let (response, run) = block_on(async {
            let started = reach_the_question(&test).await;
            let owner = &started.account.owner;
            let response =
                answer_step(&test, owner, &started.run, "approve", &answer)
                    .await;
            let run = read_run(&test, &started.account, &started.run).await;
            (response, run)
        });

        prop_assert_eq!(response.status, StatusCode::BAD_REQUEST);
        let error_body: ApiErrorBody = response.json();
        prop_assert_eq!(error_body.choices, vec!["approved", "changes"]);
        prop_assert_eq!(
            find_step(&run, "approve").status,
            StepStatus::WaitingForPerson
        );
    }

    #[test]
    fn test_answer_person_step_property_continues_the_chosen_branch(
        answer in prop_oneof![
            Just("approve"),
            Just(" Approved"),
            Just("CHANGES"),
            Just("changes "),
        ],
    ) {
        let test = TestServer::start();
        let is_approval = answer.trim().to_lowercase().starts_with("approve");
        let expected_step = if is_approval { "ship" } else { "draft" };

        let (answered, next_step) = block_on(async {
            let started = reach_the_question(&test).await;
            let owner = &started.account.owner;
            let response =
                answer_step(&test, owner, &started.run, "approve", answer)
                    .await;
            assert_eq!(response.status, StatusCode::OK, "{response:?}");
            let answered: Run = response.json();
            let next = claim_step(&test, &started.runners[0]).await;
            (answered, next.map(|assignment| assignment.step_name))
        });

        prop_assert_eq!(next_step.as_deref(), Some(expected_step));
        let expected_outcome =
            if is_approval { "approved" } else { "changes" };
        let approve = find_step(&answered, "approve");
        let answered_outcome = if is_approval {
            approve.outcome.as_deref()
        } else {
            approve
                .earlier_rounds
                .last()
                .and_then(|round| round.outcome.as_deref())
        };
        prop_assert_eq!(answered_outcome, Some(expected_outcome));
    }
}
