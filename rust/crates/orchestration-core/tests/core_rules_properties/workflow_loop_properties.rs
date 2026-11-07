use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::{
    WorkflowProblem, find_agent_by_id, validate_workflow,
};
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::loop_support::{
    LOOP_OUTCOME, build_loop_workflow, chain_workflow, loop_plan,
    rename_agents, step_name,
};
use crate::routing_fixtures::connect;
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const AGENT_COUNT: u128 = 4;
const AGENT_COUNT_SIZE: usize = 4;
const LOOP_ROUNDS: u32 = 2;

fn distinct_names() -> impl Strategy<Value = Vec<String>> {
    btree_set(".{1,10}", AGENT_COUNT_SIZE)
        .prop_map(|names| names.into_iter().collect())
}

fn forward_pair() -> impl Strategy<Value = (u128, u128)> {
    (0..AGENT_COUNT - 1)
        .prop_flat_map(|earlier| (Just(earlier), earlier + 1..AGENT_COUNT))
}

fn name_of(workflow: &Workflow, number: u128) -> String {
    find_agent_by_id(workflow, agent_identifier(number))
        .map(|agent| agent.name.clone())
        .unwrap_or_default()
}

fn renamed_forward_loop(
    names: &[String],
    earlier: u128,
    later: u128,
) -> Workflow {
    let forward_loop =
        connect(earlier, later, Some(LOOP_OUTCOME), Some(LOOP_ROUNDS));
    rename_agents(&chain_workflow(AGENT_COUNT, vec![forward_loop]), names)
}

proptest! {
    #[test]
    fn test_validate_loops_property_accepts_a_loop_to_any_earlier_step(
        plan in loop_plan(),
    ) {
        let workflow = build_loop_workflow(plan);

        prop_assert_eq!(validate_workflow(&workflow), Ok(()));
    }

    #[test]
    fn test_validate_loops_property_refuses_a_loop_to_a_later_step(
        (earlier, later) in forward_pair(),
    ) {
        let forward_loop =
            connect(earlier, later, Some(LOOP_OUTCOME), Some(LOOP_ROUNDS));
        let workflow = chain_workflow(AGENT_COUNT, vec![forward_loop]);

        prop_assert_eq!(
            validate_workflow(&workflow),
            Err(WorkflowProblem::LoopPointsForward {
                from: step_name(earlier),
                to: step_name(later),
            })
        );
    }

    #[test]
    fn test_validate_loops_property_connection_order_does_not_matter(
        (workflow, shuffled_connections) in branching_plan()
            .prop_flat_map(|plan| {
                let workflow = build_branching_workflow(&plan);
                let connections = workflow.connections.clone();
                (Just(workflow), Just(connections).prop_shuffle())
            }),
    ) {
        let shuffled =
            workflow_from_parts(workflow.agents.clone(), shuffled_connections);

        prop_assert_eq!(validate_workflow(&shuffled), Ok(()));
    }

    #[test]
    fn test_name_agent_property_a_repeated_outcome_names_its_step(
        names in distinct_names(),
        outcome in "[a-z]{1,8}",
    ) {
        let repeated = vec![
            connect(0, 1, Some(&outcome), None),
            connect(0, 2, Some(&outcome), None),
        ];
        let workflow =
            rename_agents(&chain_workflow(AGENT_COUNT, repeated), &names);

        prop_assert_eq!(
            validate_workflow(&workflow),
            Err(WorkflowProblem::DuplicateCondition {
                step_name: names[0].clone(),
                condition: outcome,
            })
        );
    }

    #[test]
    fn test_name_agent_property_a_forward_loop_names_both_steps(
        names in distinct_names(),
        (earlier, later) in forward_pair(),
    ) {
        let workflow = renamed_forward_loop(&names, earlier, later);

        prop_assert_eq!(
            validate_workflow(&workflow),
            Err(WorkflowProblem::LoopPointsForward {
                from: name_of(&workflow, earlier),
                to: name_of(&workflow, later),
            })
        );
    }

    #[test]
    fn test_name_agent_property_the_message_shows_names_not_ids(
        names in distinct_names(),
        (earlier, later) in forward_pair(),
    ) {
        let workflow = renamed_forward_loop(&names, earlier, later);

        let Err(problem) = validate_workflow(&workflow) else {
            return Err(TestCaseError::fail("a forward loop was accepted"));
        };
        let message = problem.to_string();

        prop_assert!(message.contains(&name_of(&workflow, earlier)));
        prop_assert!(message.contains(&name_of(&workflow, later)));
        for agent in &workflow.agents {
            prop_assert!(!message.contains(&agent.id.0.to_string()));
        }
    }
}
