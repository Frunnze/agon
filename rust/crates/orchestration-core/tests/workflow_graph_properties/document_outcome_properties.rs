use orchestration_core::workflow::{AgentConnection, StepKind, Workflow};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_core::workflow_graph::{
    WorkflowProblem, find_agent_by_id, validate_workflow,
};
use proptest::prelude::*;

use crate::document_reading::{
    OUTCOMES_PREFIX, document_workflow, find_block, list_step_blocks, quote,
};
use crate::routing_fixtures::{connect, routing_agent, routing_workflow};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const CONDITION: &str = "[a-z][a-z0-9-]{0,8}";
const UNKNOWN_NUMBER: u128 = 999;

fn describe_expected_outcome(
    workflow: &Workflow,
    connection: &AgentConnection,
) -> Option<String> {
    let condition = connection.condition.as_ref()?;
    let target_name = find_agent_by_id(workflow, connection.to).map_or_else(
        || connection.to.0.to_string(),
        |agent| agent.name.clone(),
    );
    let entry = match connection.round_limit {
        None => format!("{condition} -> {target_name}"),
        Some(rounds) => {
            format!("{condition} -> {target_name}, at most {rounds} rounds")
        }
    };
    Some(quote(&entry))
}

fn render_expected_outcomes(
    workflow: &Workflow,
    agent_position: usize,
) -> Option<String> {
    let agent_id = workflow.agents[agent_position].id;
    let mut entries = Vec::new();
    for connection in &workflow.connections {
        if connection.from != agent_id {
            continue;
        }
        if let Some(entry) = describe_expected_outcome(workflow, connection) {
            entries.push(entry);
        }
    }
    if entries.is_empty() {
        return None;
    }
    Some(format!("{OUTCOMES_PREFIX}[{}]", entries.join(", ")))
}

fn find_outcomes_line(document: &str, step_name: &str) -> Option<String> {
    let blocks = list_step_blocks(document);
    let block = find_block(&blocks, step_name)?;
    block
        .iter()
        .find(|line| line.starts_with(OUTCOMES_PREFIX))
        .map(|line| (*line).to_owned())
}

fn drop_conditions(workflow: &Workflow) -> Workflow {
    let mut connections = Vec::new();
    for connection in &workflow.connections {
        if connection.is_loop() {
            continue;
        }
        connections
            .push(AgentConnection::plain(connection.from, connection.to));
    }
    workflow_from_parts(workflow.agents.clone(), connections)
}

fn workflow_with_target_named(
    target_name: &str,
    outcome: &str,
    round_limit: Option<u32>,
    target: u128,
) -> Workflow {
    let mut agents = routing_workflow(3, Vec::new()).agents;
    target_name.clone_into(&mut agents[2].name);
    let mut connections = vec![connect(0, 1, None, None)];
    connections.push(connect(1, target, Some(outcome), round_limit));
    if round_limit.is_some() {
        connections.push(connect(1, 2, None, None));
    }
    workflow_from_parts(agents, connections)
}

proptest! {
    #[test]
    fn test_describe_outcomes_property_list_conditional_outputs_in_order(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for (position, agent) in workflow.agents.iter().enumerate() {
            let line = find_outcomes_line(&document, &agent.name);
            let expected = render_expected_outcomes(&workflow, position);
            prop_assert_eq!(line, expected);
        }
    }

    #[test]
    fn test_describe_outcomes_property_plain_connections_add_no_outcome(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&drop_conditions(&workflow));

        prop_assert!(!document.contains(OUTCOMES_PREFIX));
    }

    #[test]
    fn test_describe_outcomes_property_only_loops_name_their_rounds(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        let loop_count = workflow
            .connections
            .iter()
            .filter(|connection| connection.is_loop())
            .count();
        prop_assert_eq!(document.matches(" rounds\"").count(), loop_count);
    }

    #[test]
    fn test_describe_outcome_property_a_name_cannot_pose_as_a_round_limit(
        outcome in CONDITION,
        round_limit in 1..=10_u32,
        base_name in "[a-z]{1,6}",
    ) {
        let posing_name = format!("{base_name}, at most {round_limit} rounds");
        let rounds = Some(round_limit);
        let mut plain =
            workflow_with_target_named(&posing_name, &outcome, None, 2);
        plain.agents[0].name = base_name.clone();
        let mut looped =
            workflow_with_target_named(&posing_name, &outcome, rounds, 0);
        looped.agents[0].name = base_name;

        let plain_document = render_workflow_document(&plain);
        let looped_document = render_workflow_document(&looped);

        prop_assert_ne!(plain_document, looped_document);
        let is_name_refused = matches!(
            validate_workflow(&plain),
            Err(WorkflowProblem::InvalidStepName { .. })
        );
        prop_assert!(is_name_refused);
    }

    #[test]
    fn test_describe_outcome_property_plain_targets_read_unquoted(
        outcome in CONDITION,
        target_name in "[a-z][a-z0-9-]{0,10}",
        round_limit in proptest::option::of(1..=10_u32),
    ) {
        let target = if round_limit.is_some() { 0 } else { 2 };
        let mut workflow =
            workflow_with_target_named("ship", &outcome, round_limit, target);
        let target_position = if round_limit.is_some() { 0 } else { 2 };
        workflow.agents[target_position].name = target_name.clone();
        prop_assume!(validate_workflow(&workflow).is_ok());

        let document = render_workflow_document(&workflow);

        let target_text = match round_limit {
            None => target_name,
            Some(rounds) => format!("{target_name}, at most {rounds} rounds"),
        };
        let entry = quote(&format!("{outcome} -> {target_text}"));
        let line = find_outcomes_line(&document, "step-1");
        prop_assert_eq!(line, Some(format!("{OUTCOMES_PREFIX}[{entry}]")));
    }

    #[test]
    fn test_describe_outcome_property_an_unknown_target_reads_as_its_id(
        outcome in CONDITION,
    ) {
        let agents = vec![routing_agent(0, StepKind::Agent)];
        let connection = connect(0, UNKNOWN_NUMBER, Some(&outcome), None);
        let workflow = workflow_from_parts(agents, vec![connection]);

        let document = render_workflow_document(&workflow);

        let unknown_text = agent_identifier(UNKNOWN_NUMBER).0.to_string();
        let expected = quote(&format!("{outcome} -> {unknown_text}"));
        let line = find_outcomes_line(&document, "step-0");
        prop_assert_eq!(line, Some(format!("{OUTCOMES_PREFIX}[{expected}]")));
    }
}
