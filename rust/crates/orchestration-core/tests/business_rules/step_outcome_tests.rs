use orchestration_core::step_outcomes::{list_step_choices, match_choice};
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};

proptest! {
    #[test]
    fn test_match_choice_property_ignores_case_and_surrounding_space(
        choices in proptest::collection::btree_set(
            "[a-z][a-z0-9 -]{0,8}[a-z]",
            1..5,
        ),
        chosen in any::<prop::sample::Index>(),
        padding in "[ \t]{0,3}",
    ) {
        let choices: Vec<String> = choices.into_iter().collect();
        let choice = choices[chosen.index(choices.len())].clone();
        let answer = format!("{padding}{}{padding}", choice.to_uppercase());

        prop_assert_eq!(match_choice(&answer, &choices), Some(choice));
    }

    #[test]
    fn test_match_choice_property_approve_matches_an_approval_choice(
        approval_choice in prop_oneof![Just("approve"), Just("approved")],
        answer in prop_oneof![
            Just("approve"),
            Just("Approved "),
            Just("APPROVE"),
        ],
        other_choices in proptest::collection::vec("x[a-z]{1,6}", 0..3),
    ) {
        let mut choices = other_choices;
        choices.push(approval_choice.to_owned());

        prop_assert_eq!(
            match_choice(answer, &choices),
            Some(approval_choice.to_owned())
        );
    }

    #[test]
    fn test_match_choice_property_refuses_answers_that_name_no_choice(
        choices in proptest::collection::vec("[a-m]{1,6}", 0..4),
        answer in "[n-z]{1,6}",
    ) {
        prop_assert_eq!(match_choice(&answer, &choices), None);
    }

    #[test]
    fn test_list_step_choices_property_lists_every_outgoing_outcome_once(
        plan in branching_plan(),
    ) {
        let workflow = build_branching_workflow(&plan);

        for agent in &workflow.agents {
            let choices = list_step_choices(&workflow, agent.id);
            let expected: Vec<String> = workflow
                .connections
                .iter()
                .filter(|connection| connection.from == agent.id)
                .filter_map(|connection| connection.condition.clone())
                .collect();
            prop_assert_eq!(choices, expected);
        }
    }
}
