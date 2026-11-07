use orchestration_core::connection_rules::{
    MAXIMUM_CONDITION_LENGTH, ROUND_LIMITS,
};
use orchestration_core::workflow_graph::{WorkflowProblem, validate_workflow};
use proptest::collection::{btree_set, vec};
use proptest::prelude::*;

use crate::loop_support::{LOOP_OUTCOME, chain_workflow, step_name};
use crate::routing_fixtures::{connect, routing_workflow};

const ALLOWED_PUNCTUATION: [char; 2] = [' ', '-'];
const MAXIMUM_FAN_OUT: usize = 5;

fn is_model_condition(condition: &str) -> bool {
    let length = condition.chars().count();
    let has_allowed_length = length != 0 && length <= MAXIMUM_CONDITION_LENGTH;
    let has_allowed_characters = condition.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || ALLOWED_PUNCTUATION.contains(&character)
    });
    let has_no_edge_space =
        !condition.starts_with(' ') && !condition.ends_with(' ');
    has_allowed_length && has_allowed_characters && has_no_edge_space
}

fn mixed_condition() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-z0-9 -]{0,45}",
        "[a-zA-Z0-9 _\\-\t\u{e9}\u{663}]{0,12}",
        ".{0,8}",
    ]
}

fn written_condition() -> impl Strategy<Value = String> {
    "[a-z0-9-]([a-z0-9 -]{0,38}[a-z0-9-])?"
}

proptest! {
    #[test]
    fn test_is_well_formed_condition_property_matches_the_outcome_rule(
        condition in mixed_condition(),
    ) {
        let workflow =
            routing_workflow(2, vec![connect(0, 1, Some(&condition), None)]);

        let verdict = validate_workflow(&workflow);

        if is_model_condition(&condition) {
            prop_assert_eq!(verdict, Ok(()));
        } else {
            prop_assert_eq!(
                verdict,
                Err(WorkflowProblem::InvalidCondition { condition })
            );
        }
    }

    #[test]
    fn test_is_well_formed_condition_property_counts_characters_not_bytes(
        length in 1..=MAXIMUM_CONDITION_LENGTH + 5,
    ) {
        let condition = "a".repeat(length);
        let workflow =
            routing_workflow(2, vec![connect(0, 1, Some(&condition), None)]);

        let is_accepted = validate_workflow(&workflow).is_ok();

        prop_assert_eq!(is_accepted, length <= MAXIMUM_CONDITION_LENGTH);
    }

    #[test]
    fn test_is_well_formed_condition_property_refuses_a_space_at_either_end(
        condition in written_condition(),
        is_leading in any::<bool>(),
    ) {
        let spaced = if is_leading {
            format!(" {condition}")
        } else {
            format!("{condition} ")
        };
        let workflow =
            routing_workflow(2, vec![connect(0, 1, Some(&spaced), None)]);

        prop_assert_eq!(
            validate_workflow(&workflow),
            Err(WorkflowProblem::InvalidCondition { condition: spaced })
        );
    }

    #[test]
    fn test_validate_conditions_property_distinct_outcomes_fan_out(
        outcomes in btree_set(written_condition(), 1..MAXIMUM_FAN_OUT),
    ) {
        let mut connections = Vec::new();
        let mut agent_count = 1;
        for outcome in &outcomes {
            connections.push(connect(0, agent_count, Some(outcome), None));
            agent_count += 1;
        }
        let workflow = routing_workflow(agent_count, connections);

        prop_assert_eq!(validate_workflow(&workflow), Ok(()));
    }

    #[test]
    fn test_validate_conditions_property_steps_may_reuse_outcome_names(
        outcome in written_condition(),
        agent_count in 3_u128..6,
    ) {
        let mut connections = Vec::new();
        for number in 1..agent_count {
            let connection = connect(number - 1, number, Some(&outcome), None);
            connections.push(connection);
        }
        let workflow = routing_workflow(agent_count, connections);

        prop_assert_eq!(validate_workflow(&workflow), Ok(()));
    }

    #[test]
    fn test_validate_conditions_property_refuses_a_repeat_from_one_step(
        outcome in written_condition(),
        targets in vec(1_u128..4, 2..4),
    ) {
        let mut connections = Vec::new();
        for target in &targets {
            connections.push(connect(0, *target, Some(&outcome), None));
        }
        let workflow = routing_workflow(4, connections);

        prop_assert_eq!(
            validate_workflow(&workflow),
            Err(WorkflowProblem::DuplicateCondition {
                step_name: step_name(0),
                condition: outcome,
            })
        );
    }

    #[test]
    fn test_validate_round_limit_property_accepts_every_allowed_limit(
        round_limit in ROUND_LIMITS,
        agent_count in 2_u128..6,
    ) {
        let back_loop = connect(
            agent_count - 1,
            0,
            Some(LOOP_OUTCOME),
            Some(round_limit),
        );
        let workflow = chain_workflow(agent_count, vec![back_loop]);

        prop_assert_eq!(validate_workflow(&workflow), Ok(()));
    }

    #[test]
    fn test_validate_round_limit_property_refuses_limits_out_of_range(
        round_limit in prop_oneof![
            Just(0_u32),
            Just(*ROUND_LIMITS.end() + 1),
            Just(u32::MAX),
            any::<u32>(),
        ],
    ) {
        let back_loop =
            connect(1, 0, Some(LOOP_OUTCOME), Some(round_limit));
        let workflow = chain_workflow(2, vec![back_loop]);

        let verdict = validate_workflow(&workflow);

        if ROUND_LIMITS.contains(&round_limit) {
            prop_assert_eq!(verdict, Ok(()));
        } else {
            prop_assert_eq!(
                verdict,
                Err(WorkflowProblem::InvalidRoundLimit { round_limit })
            );
        }
    }

    #[test]
    fn test_validate_round_limit_property_a_limit_needs_an_outcome(
        round_limit in ROUND_LIMITS,
        agent_count in 2_u128..6,
    ) {
        let back_loop = connect(agent_count - 1, 0, None, Some(round_limit));
        let workflow = chain_workflow(agent_count, vec![back_loop]);

        prop_assert_eq!(
            validate_workflow(&workflow),
            Err(WorkflowProblem::LoopWithoutCondition)
        );
    }
}
