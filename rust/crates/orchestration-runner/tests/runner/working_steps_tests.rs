use orchestration_runner::working_steps::{Departure, WorkingSteps};
use proptest::collection::vec;
use proptest::prelude::*;

const MOST_STEPS: usize = 8;
const MOST_MOVES: usize = 40;

#[derive(Clone, Debug)]
struct LeavingStep {
    subject: String,
    has_changes: bool,
}

fn any_leaving_order() -> impl Strategy<Value = Vec<LeavingStep>> {
    (1..=MOST_STEPS).prop_flat_map(|step_count| {
        let step_numbers: Vec<usize> = (0..step_count).collect();
        let shuffled_numbers = Just(step_numbers).prop_shuffle();
        let change_marks = vec(any::<bool>(), step_count);
        (shuffled_numbers, change_marks).prop_map(
            |(shuffled_numbers, change_marks)| {
                let mut leaving_steps = Vec::new();
                for (number, has_changes) in
                    shuffled_numbers.into_iter().zip(change_marks)
                {
                    leaving_steps.push(LeavingStep {
                        subject: format!("step-{number}: changes"),
                        has_changes,
                    });
                }
                leaving_steps
            },
        )
    })
}

fn leave_step(
    working_steps: &mut WorkingSteps,
    leaving_step: &LeavingStep,
) -> Departure {
    if leaving_step.has_changes {
        return working_steps.leave_with_changes(leaving_step.subject.clone());
    }
    working_steps.leave()
}

fn enter_steps(step_count: usize) -> WorkingSteps {
    let mut working_steps = WorkingSteps::default();
    for _ in 0..step_count {
        working_steps.enter();
    }
    working_steps
}

proptest! {
    #[test]
    fn test_enter_property_keeps_others_working_until_the_last_one_leaves(
        step_count in 2..=MOST_STEPS,
    ) {
        let mut working_steps = enter_steps(step_count);

        for _ in 1..step_count {
            prop_assert_eq!(
                working_steps.leave(),
                Departure::OthersStillWorking
            );
        }
        prop_assert_eq!(working_steps.leave(), Departure::LastOut);
    }

    #[test]
    fn test_leave_property_reports_last_out_exactly_when_nobody_works(
        moves in vec(any::<bool>(), 1..MOST_MOVES),
    ) {
        let mut working_steps = WorkingSteps::default();
        let mut still_working: usize = 0;

        for is_entering in moves {
            if is_entering || still_working == 0 {
                working_steps.enter();
                still_working += 1;
                continue;
            }
            still_working -= 1;
            let expected = if still_working == 0 {
                Departure::LastOut
            } else {
                Departure::OthersStillWorking
            };
            prop_assert_eq!(working_steps.leave(), expected);
        }
    }

    #[test]
    fn test_leave_with_changes_property_reports_last_out_once_in_any_order(
        leaving_order in any_leaving_order(),
    ) {
        let mut working_steps = enter_steps(leaving_order.len());

        let mut departures = Vec::new();
        for leaving_step in &leaving_order {
            departures.push(leave_step(&mut working_steps, leaving_step));
        }

        let last_out_count = departures
            .iter()
            .filter(|departure| **departure == Departure::LastOut)
            .count();
        prop_assert_eq!(last_out_count, 1);
        prop_assert_eq!(departures.last(), Some(&Departure::LastOut));
    }

    #[test]
    fn test_take_uncommitted_step_subjects_property_hands_each_over_once(
        leaving_order in any_leaving_order(),
    ) {
        let mut working_steps = enter_steps(leaving_order.len());
        let mut expected_subjects = Vec::new();
        for leaving_step in &leaving_order {
            leave_step(&mut working_steps, leaving_step);
            if leaving_step.has_changes {
                expected_subjects.push(leaving_step.subject.clone());
            }
        }

        let taken_subjects = working_steps.take_uncommitted_step_subjects();
        let taken_again = working_steps.take_uncommitted_step_subjects();

        prop_assert_eq!(taken_subjects, expected_subjects);
        prop_assert!(taken_again.is_empty());
    }
}
