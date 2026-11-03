use orchestration_core::workflow::{AgentConnection, Workflow};
use orchestration_core::workflow_graph::{WorkflowProblem, validate_workflow};
use proptest::prelude::*;

use crate::branching_strategies::{
    branching_plan, build_branching_workflow, list_back_pairs,
};

const TOO_MANY_ROUNDS: u32 = 11;

fn with_connection(
    workflow: &Workflow,
    connection: AgentConnection,
) -> Workflow {
    let mut connections = workflow.connections.clone();
    connections.push(connection);
    Workflow {
        connections,
        ..workflow.clone()
    }
}

fn first_back_pair(workflow: &Workflow) -> Option<(usize, usize)> {
    list_back_pairs(workflow).first().copied()
}

proptest! {
    #[test]
    fn test_validate_workflow_property_accepts_forks_loops_and_person_steps(
        plan in branching_plan(),
    ) {
        let workflow = build_branching_workflow(&plan);

        prop_assert_eq!(validate_workflow(&workflow), Ok(()));
    }

    #[test]
    fn test_validate_workflow_property_refuses_a_back_edge_without_a_limit(
        plan in branching_plan(),
        is_conditioned in any::<bool>(),
    ) {
        let workflow = build_branching_workflow(&plan);
        let Some((from, to)) = first_back_pair(&workflow) else {
            return Ok(());
        };
        let condition = is_conditioned.then(|| "back again".to_owned());
        let back_edge = AgentConnection {
            condition,
            ..AgentConnection::plain(
                workflow.agents[from].id,
                workflow.agents[to].id,
            )
        };

        let extended = with_connection(&workflow, back_edge);
        let verdict = validate_workflow(&extended);

        prop_assert_eq!(verdict, Err(WorkflowProblem::Cycle));
    }

    #[test]
    fn test_validate_workflow_property_refuses_a_loop_without_condition(
        plan in branching_plan(),
        round_limit in 1_u32..=10,
    ) {
        let workflow = build_branching_workflow(&plan);
        let Some((from, to)) = first_back_pair(&workflow) else {
            return Ok(());
        };
        let loop_edge = AgentConnection {
            round_limit: Some(round_limit),
            ..AgentConnection::plain(
                workflow.agents[from].id,
                workflow.agents[to].id,
            )
        };

        let extended = with_connection(&workflow, loop_edge);
        let verdict = validate_workflow(&extended);

        prop_assert_eq!(verdict, Err(WorkflowProblem::LoopWithoutCondition));
    }

    #[test]
    fn test_validate_workflow_property_refuses_round_limits_out_of_range(
        plan in branching_plan(),
        round_limit in prop_oneof![Just(0_u32), TOO_MANY_ROUNDS..],
    ) {
        let workflow = build_branching_workflow(&plan);
        let Some((from, to)) = first_back_pair(&workflow) else {
            return Ok(());
        };
        let loop_edge = AgentConnection {
            from: workflow.agents[from].id,
            to: workflow.agents[to].id,
            condition: Some("again".to_owned()),
            round_limit: Some(round_limit),
        };

        let extended = with_connection(&workflow, loop_edge);
        let verdict = validate_workflow(&extended);

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::InvalidRoundLimit { round_limit })
        );
    }

    #[test]
    fn test_validate_workflow_property_refuses_repeated_outcome_names(
        plan in branching_plan(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let workflow = build_branching_workflow(&plan);
        let conditioned: Vec<&AgentConnection> = workflow
            .connections
            .iter()
            .filter(|connection| connection.condition.is_some())
            .collect();
        if conditioned.is_empty() {
            return Ok(());
        }
        let copied = conditioned[chosen.index(conditioned.len())].clone();
        let source_name = workflow
            .agents
            .iter()
            .find(|agent| agent.id == copied.from)
            .map(|agent| agent.name.clone())
            .unwrap_or_default();
        let condition = copied.condition.clone().unwrap_or_default();

        let verdict = validate_workflow(&with_connection(&workflow, copied));

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::DuplicateCondition {
                step_name: source_name,
                condition,
            })
        );
    }

    #[test]
    fn test_validate_workflow_property_refuses_loops_that_point_forward(
        plan in branching_plan(),
    ) {
        let workflow = build_branching_workflow(&plan);
        let Some((later, earlier)) = first_back_pair(&workflow) else {
            return Ok(());
        };
        let forward_loop = AgentConnection {
            from: workflow.agents[earlier].id,
            to: workflow.agents[later].id,
            condition: Some("onward".to_owned()),
            round_limit: Some(1),
        };

        let verdict =
            validate_workflow(&with_connection(&workflow, forward_loop));

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::LoopPointsForward {
                from: workflow.agents[earlier].name.clone(),
                to: workflow.agents[later].name.clone(),
            })
        );
    }

    #[test]
    fn test_validate_workflow_property_refuses_malformed_outcome_names(
        plan in branching_plan(),
        condition in prop_oneof![
            Just(String::new()),
            Just(" padded".to_owned()),
            "[A-Z_.!]{1,5}",
            "[a-z]{41,50}",
        ],
    ) {
        let workflow = build_branching_workflow(&plan);
        let Some((later, earlier)) = first_back_pair(&workflow) else {
            return Ok(());
        };
        let malformed = AgentConnection {
            condition: Some(condition.clone()),
            ..AgentConnection::plain(
                workflow.agents[earlier].id,
                workflow.agents[later].id,
            )
        };

        let extended = with_connection(&workflow, malformed);
        let verdict = validate_workflow(&extended);

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::InvalidCondition { condition })
        );
    }
}
