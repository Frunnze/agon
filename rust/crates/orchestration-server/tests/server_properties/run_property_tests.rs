use axum::http::StatusCode;
use orchestration_api::work::RunEvent;
use orchestration_core::run::{LogLine, StepStatus};
use orchestration_core::run_lifecycle::apply_step_status;
use proptest::prelude::*;

use crate::fixtures::SEALED_DETAILS;
use crate::run_fixtures::{post_events, start_claimed_run};
use crate::test_client::{TestServer, block_on};

fn step_status_strategy() -> impl Strategy<Value = StepStatus> {
    prop_oneof![
        Just(StepStatus::Waiting),
        Just(StepStatus::Running),
        Just(StepStatus::WaitingForApproval),
        Just(StepStatus::Done),
        Just(StepStatus::Failed),
        Just(StepStatus::Skipped),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_post_run_events_property_steps_follow_the_core_rules(
        statuses in proptest::collection::vec(step_status_strategy(), 1..6),
    ) {
        let test = TestServer::start();
        let (claimed_run, observed) = block_on(async {
            let claimed = start_claimed_run(&test).await;
            let step_name = claimed.run.steps[0].name.clone();
            let mut observed = Vec::new();
            for status in &statuses {
                let event = RunEvent::StepStatusChanged {
                    step_name: step_name.clone(),
                    status: *status,
                };
                let events = vec![event];
                let outcome =
                    post_events(&test, &claimed.holder, &claimed.run, events)
                        .await;
                observed.push(outcome);
            }
            (claimed.run, observed)
        });

        let step_name = claimed_run.steps[0].name.clone();
        let mut expected_run = claimed_run;
        for (status, (response_status, updated_run)) in
            statuses.iter().zip(observed)
        {
            let now = test.now();
            match apply_step_status(&expected_run, &step_name, *status, now) {
                Ok(next_run) => {
                    prop_assert_eq!(response_status, StatusCode::OK);
                    prop_assert_eq!(updated_run.as_ref(), Some(&next_run));
                    expected_run = next_run;
                }
                Err(_) => {
                    prop_assert_eq!(response_status, StatusCode::CONFLICT);
                }
            }
        }
    }

    #[test]
    fn test_post_run_events_property_log_lines_keep_their_order(
        line_count in 0_usize..12,
    ) {
        let test = TestServer::start();
        let (updated_run, step_name) = block_on(async {
            let claimed = start_claimed_run(&test).await;
            let step_name = claimed.run.steps[0].name.clone();
            let events: Vec<RunEvent> = (0..line_count)
                .map(|position| RunEvent::LogAppended {
                    line: LogLine {
                        at: test.now(),
                        step_name: step_name.clone(),
                        text: format!("{SEALED_DETAILS}{position}"),
                        is_error: false,
                    },
                })
                .collect();
            let holder = &claimed.holder;
            let (_status, updated_run) =
                post_events(&test, holder, &claimed.run, events).await;
            (updated_run, step_name)
        });

        let updated_run = updated_run.expect("the runner may post log lines");
        prop_assert_eq!(updated_run.log.len(), line_count);
        for (position, line) in updated_run.log.iter().enumerate() {
            prop_assert_eq!(&line.step_name, &step_name);
            let expected_text = format!("{SEALED_DETAILS}{position}");
            prop_assert_eq!(&line.text, &expected_text);
        }
    }
}
