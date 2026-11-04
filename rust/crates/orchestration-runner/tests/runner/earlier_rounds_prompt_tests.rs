use orchestration_core::run::{EarlierStepRound, StepStatus};
use orchestration_runner::earlier_rounds_prompt::describe_earlier_rounds;
use proptest::collection::vec;
use proptest::option::of;
use proptest::prelude::*;

const HEADING: &str = "## This step's earlier rounds";
const ROUND_HEADING_PREFIX: &str = "### Round ";
const TEXT_PATTERN: &str = "[a-zA-Z0-9][a-zA-Z0-9 .,]{0,30}";
const MOST_EARLIER_ROUNDS: usize = 6;

fn any_earlier_round() -> impl Strategy<Value = EarlierStepRound> {
    let statuses =
        prop_oneof![Just(StepStatus::Done), Just(StepStatus::Skipped)];
    (statuses, of(TEXT_PATTERN), of("[a-z]{1,10}")).prop_map(
        |(status, result, outcome)| EarlierStepRound {
            status,
            started_at: None,
            finished_at: None,
            result,
            outcome,
        },
    )
}

fn describe_round_sentence(
    earlier_round_count: usize,
    loop_round_limit: Option<u32>,
) -> String {
    let current_round = earlier_round_count + 1;
    match loop_round_limit {
        Some(round_limit) => format!(
            "This is round {current_round} of {} of this step.",
            round_limit + 1
        ),
        None => format!("This is round {current_round} of this step."),
    }
}

proptest! {
    #[test]
    fn test_describe_earlier_rounds_property_counts_on_and_keeps_the_order(
        earlier_rounds in vec(any_earlier_round(), 1..=MOST_EARLIER_ROUNDS),
        loop_round_limit in of(1_u32..=10),
    ) {
        let described =
            describe_earlier_rounds(&earlier_rounds, loop_round_limit);

        let Some(section) = described else {
            return Err(TestCaseError::fail("earlier rounds are described"));
        };
        let sentence =
            describe_round_sentence(earlier_rounds.len(), loop_round_limit);
        let opening = format!("{HEADING}\n{sentence}");
        prop_assert!(section.starts_with(&opening), "{}", section);
        let mut searched_from = 0;
        for (index, round) in earlier_rounds.iter().enumerate() {
            let round_number = index + 1;
            let round_heading =
                format!("{ROUND_HEADING_PREFIX}{round_number}");
            let mut parts = vec![round_heading];
            if let Some(outcome) = &round.outcome {
                parts.push(format!("Outcome: {outcome}"));
            }
            parts.extend(round.result.clone());
            for part in parts {
                let found_at = section[searched_from..].find(&part);
                let Some(found_at) = found_at else {
                    return Err(TestCaseError::fail(part));
                };
                searched_from += found_at + part.len();
            }
        }
        let listed = section.matches(ROUND_HEADING_PREFIX).count();
        prop_assert_eq!(listed, earlier_rounds.len());
    }

    #[test]
    fn test_describe_earlier_rounds_property_leaves_a_first_round_alone(
        loop_round_limit in of(1_u32..=10),
    ) {
        prop_assert_eq!(describe_earlier_rounds(&[], loop_round_limit), None);
    }
}

#[test]
fn describes_each_earlier_round_plainly() {
    let rounds = [
        EarlierStepRound {
            status: StepStatus::Done,
            started_at: None,
            finished_at: None,
            result: Some("Needs tests.\nOUTCOME: changes".to_owned()),
            outcome: Some("changes".to_owned()),
        },
        EarlierStepRound {
            status: StepStatus::Skipped,
            started_at: None,
            finished_at: None,
            result: None,
            outcome: None,
        },
    ];

    let described = describe_earlier_rounds(&rounds, Some(3));

    let expected = "## This step's earlier rounds\n\
        This is round 3 of 4 of this step.\n\n\
        ### Round 1\nOutcome: changes\nNeeds tests.\nOUTCOME: changes\n\n\
        ### Round 2\nThis round was skipped.";
    assert_eq!(described.as_deref(), Some(expected));
}
