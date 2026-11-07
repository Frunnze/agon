use orchestration_core::workflow::{
    AgentConnection, StepKind, Workflow, WorkflowAgent,
};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_core::workflow_graph::validate_workflow;
use proptest::collection::{btree_set, vec};
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::document_connection_reading::read_document_connections;
use crate::routing_fixtures::{connect, routing_agent, routing_workflow};
use crate::signing_gap_support::{
    agent_count, candidate_count, list_candidate_connections,
    list_named_connections, pick_connections,
};
use crate::workflow_strategies::workflow_from_parts;

const STEP_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,10}";
const OUTCOME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const COLLISION_STEP_COUNT: usize = 3;
const COLLISION_OUTCOME_COUNT: usize = 2;
const SOURCE_STEP: u128 = 0;
const SHARED_TARGET_STEP: u128 = 1;
const OTHER_TARGET_STEP: u128 = 2;

fn toggle_plain_picks(
    candidates: &[AgentConnection],
    picks: &[bool],
    plain_toggles: &[bool],
) -> Vec<bool> {
    let mut toggled_picks = Vec::new();
    for ((candidate, is_picked), is_toggled) in
        candidates.iter().zip(picks).zip(plain_toggles)
    {
        let flips_plain_copy = candidate.condition.is_none() && *is_toggled;
        toggled_picks.push(*is_picked != flips_plain_copy);
    }
    toggled_picks
}

fn workflows_differing_in_plain_copies()
-> impl Strategy<Value = (Workflow, Workflow)> {
    agent_count()
        .prop_flat_map(|agent_count| {
            let count = candidate_count(agent_count);
            (
                Just(agent_count),
                vec(any::<bool>(), count),
                vec(any::<bool>(), count),
            )
        })
        .prop_map(|(agent_count, picks, plain_toggles)| {
            let candidates = list_candidate_connections(agent_count);
            let toggled_picks =
                toggle_plain_picks(&candidates, &picks, &plain_toggles);
            let first_connections = pick_connections(&candidates, &picks);
            let second_connections =
                pick_connections(&candidates, &toggled_picks);
            (
                routing_workflow(agent_count, first_connections),
                routing_workflow(agent_count, second_connections),
            )
        })
}

fn add_plain_copy(workflow: &Workflow, pick: prop::sample::Index) -> Workflow {
    let conditional_forward: Vec<&AgentConnection> = workflow
        .connections
        .iter()
        .filter(|connection| {
            connection.condition.is_some() && !connection.is_loop()
        })
        .collect();
    if conditional_forward.is_empty() {
        return workflow.clone();
    }
    let copied = conditional_forward[pick.index(conditional_forward.len())];
    let mut connections = workflow.connections.clone();
    connections.push(AgentConnection::plain(copied.from, copied.to));
    workflow_from_parts(workflow.agents.clone(), connections)
}

fn branching_workflow_with_plain_copy() -> impl Strategy<Value = Workflow> {
    (
        branching_plan(),
        any::<bool>(),
        any::<prop::sample::Index>(),
    )
        .prop_map(|(plan, adds_plain_copy, pick)| {
            let workflow = build_branching_workflow(&plan);
            if adds_plain_copy {
                return add_plain_copy(&workflow, pick);
            }
            workflow
        })
}

fn collision_workflow(
    step_names: &[String],
    connections: Vec<AgentConnection>,
) -> Workflow {
    let mut agents = Vec::new();
    for (number, name) in (0_u128..).zip(step_names) {
        let agent = routing_agent(number, StepKind::Agent);
        agents.push(WorkflowAgent {
            name: name.clone(),
            ..agent
        });
    }
    workflow_from_parts(agents, connections)
}

fn collision_parts() -> impl Strategy<Value = (Vec<String>, Vec<String>)> {
    (
        btree_set(STEP_NAME_PATTERN, COLLISION_STEP_COUNT),
        btree_set(OUTCOME_PATTERN, COLLISION_OUTCOME_COUNT),
    )
        .prop_flat_map(|(step_names, outcomes)| {
            let named_steps: Vec<String> = step_names.into_iter().collect();
            let outcome_names: Vec<String> = outcomes.into_iter().collect();
            (Just(named_steps).prop_shuffle(), Just(outcome_names))
        })
}

proptest! {
    #[test]
    fn test_render_workflow_document_property_same_document_same_behaviour(
        (first, second) in workflows_differing_in_plain_copies(),
    ) {
        let both_valid = validate_workflow(&first).is_ok()
            && validate_workflow(&second).is_ok();
        let first_document = render_workflow_document(&first);
        let second_document = render_workflow_document(&second);

        if both_valid && first_document == second_document {
            prop_assert_eq!(
                list_named_connections(&first),
                list_named_connections(&second)
            );
        }
    }

    #[test]
    fn test_render_workflow_document_property_reads_back_every_connection(
        workflow in branching_workflow_with_plain_copy(),
    ) {
        let verdict = validate_workflow(&workflow);
        let document = render_workflow_document(&workflow);

        if verdict.is_ok() {
            prop_assert_eq!(
                read_document_connections(&document),
                list_named_connections(&workflow)
            );
        }
    }

    #[test]
    fn test_render_workflow_document_property_reported_collision_is_refused(
        (step_names, outcomes) in collision_parts(),
        connection_order in Just(vec![0_usize, 1, 2]).prop_shuffle(),
    ) {
        let candidate_connections = [
            connect(SOURCE_STEP, SHARED_TARGET_STEP, None, None),
            connect(
                SOURCE_STEP,
                SHARED_TARGET_STEP,
                Some(&outcomes[0]),
                None,
            ),
            connect(SOURCE_STEP, OTHER_TARGET_STEP, Some(&outcomes[1]), None),
        ];
        let mut with_plain_copy = Vec::new();
        let mut without_plain_copy = Vec::new();
        for position in connection_order {
            let connection = candidate_connections[position].clone();
            if connection.condition.is_some() {
                without_plain_copy.push(connection.clone());
            }
            with_plain_copy.push(connection);
        }
        let colliding = collision_workflow(&step_names, with_plain_copy);
        let honest = collision_workflow(&step_names, without_plain_copy);

        let colliding_document = render_workflow_document(&colliding);
        let honest_document = render_workflow_document(&honest);

        prop_assert_eq!(colliding_document, honest_document);
        prop_assert_eq!(validate_workflow(&honest), Ok(()));
        prop_assert!(validate_workflow(&colliding).is_err());
    }
}
