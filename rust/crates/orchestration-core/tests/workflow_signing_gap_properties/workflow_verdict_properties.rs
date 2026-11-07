use std::collections::BTreeSet;
use std::mem::discriminant;

use orchestration_core::naming::validate_name;
use orchestration_core::workflow::{AgentConnection, Workflow};
use orchestration_core::workflow_graph::{WorkflowProblem, validate_workflow};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::routing_fixtures::routing_workflow;
use crate::signing_gap_support::{
    agent_count, candidate_count, list_candidate_connections, name_agent,
    pick_connections,
};
use crate::workflow_strategies::{arbitrary_workflow, workflow_from_parts};

fn has_distinct_pairs(workflow: &Workflow) -> bool {
    let mut seen_pairs = BTreeSet::new();
    workflow
        .connections
        .iter()
        .all(|connection| seen_pairs.insert((connection.from, connection.to)))
}

fn follows_the_naming_rule(workflow: &Workflow) -> bool {
    workflow
        .agents
        .iter()
        .all(|agent| validate_name(&agent.name).is_ok())
}

fn candidate_workflow() -> impl Strategy<Value = Workflow> {
    agent_count()
        .prop_flat_map(|agent_count| {
            let count = candidate_count(agent_count);
            (Just(agent_count), vec(any::<bool>(), count))
        })
        .prop_map(|(agent_count, picks)| {
            let candidates = list_candidate_connections(agent_count);
            let connections = pick_connections(&candidates, &picks);
            routing_workflow(agent_count, connections)
        })
}

fn shuffled_connections_of(
    workflow: Workflow,
) -> impl Strategy<Value = (Workflow, Vec<AgentConnection>)> {
    let connections = workflow.connections.clone();
    (Just(workflow), Just(connections).prop_shuffle())
}

proptest! {
    #[test]
    fn test_validate_workflow_property_accepted_workflows_obey_the_editor(
        workflow in prop_oneof![arbitrary_workflow(), candidate_workflow()],
    ) {
        let verdict = validate_workflow(&workflow);

        if verdict.is_ok() {
            prop_assert!(has_distinct_pairs(&workflow));
            prop_assert!(follows_the_naming_rule(&workflow));
        }
    }

    #[test]
    fn test_validate_workflow_property_verdict_ignores_connection_order(
        (workflow, shuffled) in
            candidate_workflow().prop_flat_map(shuffled_connections_of),
    ) {
        let reordered =
            workflow_from_parts(workflow.agents.clone(), shuffled);

        let verdict = validate_workflow(&workflow);
        let reordered_verdict = validate_workflow(&reordered);

        prop_assert_eq!(verdict.is_ok(), reordered_verdict.is_ok());
        if let (Err(problem), Err(reordered_problem)) =
            (verdict, reordered_verdict)
        {
            prop_assert_eq!(
                discriminant(&problem),
                discriminant(&reordered_problem)
            );
        }
    }

    #[test]
    fn test_validate_workflow_property_a_copy_of_any_connection_is_refused(
        plan in branching_plan(),
        pick in any::<prop::sample::Index>(),
        is_copy_plain in any::<bool>(),
    ) {
        let workflow = build_branching_workflow(&plan);
        prop_assume!(!workflow.connections.is_empty());
        prop_assume!(validate_workflow(&workflow).is_ok());
        let copied_position = pick.index(workflow.connections.len());
        let copied = &workflow.connections[copied_position];
        let copy = if is_copy_plain {
            AgentConnection::plain(copied.from, copied.to)
        } else {
            copied.clone()
        };
        let mut connections = workflow.connections.clone();
        connections.push(copy);
        let repeated =
            workflow_from_parts(workflow.agents.clone(), connections);

        let verdict = validate_workflow(&repeated);

        prop_assert!(verdict.is_err());
        let is_plain_pair = is_copy_plain || copied.condition.is_none();
        if is_plain_pair && !copied.is_loop() {
            prop_assert_eq!(
                verdict,
                Err(WorkflowProblem::RepeatedConnection {
                    from: name_agent(&workflow, copied.from),
                    to: name_agent(&workflow, copied.to),
                })
            );
        }
    }
}
