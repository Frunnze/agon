use std::collections::BTreeSet;

use chrono::DateTime;
use orchestration_core::run_lifecycle::create_run;
use orchestration_core::task::{Task, TaskDoer};
use orchestration_core::workflow::{
    AgentConnection, CanvasPosition, StepKind, Workflow, WorkflowAgent,
};
use orchestration_core::workflow_graph::{
    agents_in_order, forward_reachable_agents, validate_workflow,
};
use proptest::prelude::*;
use serde::Deserialize;

use crate::entity_strategies::example_task;
use crate::routing_fixtures::routing_agent;
use crate::run_fixtures::{RUN_NUMBER, run_identifier, starter};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const UNKNOWN_NUMBER: u128 = 999;
const LARGEST_CASE_AGENT_COUNT: usize = 6;
const SHARED_GRAPH_CASES: &str =
    include_str!("../fixtures/workflow_graph_cases.json");

#[derive(Debug, Deserialize)]
struct SharedAgent {
    name: String,
    horizontal: f64,
    vertical: f64,
    id_number: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct SharedConnection {
    from: String,
    to: String,
    condition: Option<String>,
    round_limit: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct SharedGraphCase {
    description: String,
    agents: Vec<SharedAgent>,
    connections: Vec<SharedConnection>,
    order: Vec<String>,
    is_valid: bool,
    run_steps: Option<Vec<String>>,
    reached_from_first: Vec<String>,
}

fn read_shared_cases() -> Result<Vec<SharedGraphCase>, serde_json::Error> {
    serde_json::from_str(SHARED_GRAPH_CASES)
}

fn identify_number(position: u128, agent: &SharedAgent) -> u128 {
    agent.id_number.map_or(position, u128::from)
}

fn find_number(case: &SharedGraphCase, name: &str) -> u128 {
    (0_u128..)
        .zip(&case.agents)
        .find(|(_, agent)| agent.name == name)
        .map_or(UNKNOWN_NUMBER, |(position, agent)| {
            identify_number(position, agent)
        })
}

fn build_case_workflow(
    case: &SharedGraphCase,
    storage_order: &[usize],
) -> Workflow {
    let mut numbered_agents = Vec::new();
    for (position, agent) in (0_u128..).zip(&case.agents) {
        let number = identify_number(position, agent);
        numbered_agents.push(WorkflowAgent {
            name: agent.name.clone(),
            position: CanvasPosition {
                horizontal: agent.horizontal,
                vertical: agent.vertical,
            },
            ..routing_agent(number, StepKind::Agent)
        });
    }
    let mut agents = Vec::new();
    for position in storage_order {
        agents.push(numbered_agents[*position].clone());
    }

    let mut connections = Vec::new();
    for connection in &case.connections {
        connections.push(AgentConnection {
            from: agent_identifier(find_number(case, &connection.from)),
            to: agent_identifier(find_number(case, &connection.to)),
            condition: connection.condition.clone(),
            round_limit: connection.round_limit,
        });
    }
    workflow_from_parts(agents, connections)
}

fn stored_order(case: &SharedGraphCase) -> Vec<usize> {
    (0..case.agents.len()).collect()
}

fn list_names_in_order(workflow: &Workflow) -> Vec<String> {
    agents_in_order(workflow)
        .iter()
        .map(|agent| agent.name.clone())
        .collect()
}

fn list_reached_names(workflow: &Workflow) -> BTreeSet<String> {
    let first_id = agent_identifier(0);
    let reached_ids = forward_reachable_agents(workflow, first_id);
    let mut names = BTreeSet::new();
    for agent in &workflow.agents {
        if reached_ids.contains(&agent.id) {
            names.insert(agent.name.clone());
        }
    }
    names
}

fn plan_run_step_names(workflow: &Workflow) -> Option<Vec<String>> {
    let task = Task {
        doer: TaskDoer::Workflow {
            workflow_id: workflow.id,
        },
        ..example_task()
    };
    let run = create_run(
        &task,
        Some(workflow),
        RUN_NUMBER,
        run_identifier(),
        starter(),
        DateTime::UNIX_EPOCH,
    )
    .ok()?;
    Some(run.steps.into_iter().map(|step| step.name).collect())
}

#[test]
fn test_agents_in_order_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let workflow = build_case_workflow(&case, &stored_order(&case));

        let names = list_names_in_order(&workflow);

        assert_eq!(names, case.order, "{}", case.description);
    }
    Ok(())
}

#[test]
fn test_validate_workflow_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let workflow = build_case_workflow(&case, &stored_order(&case));

        let verdict = validate_workflow(&workflow);

        assert_eq!(verdict.is_ok(), case.is_valid, "{}", case.description);
    }
    Ok(())
}

#[test]
fn test_forward_reachable_agents_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let workflow = build_case_workflow(&case, &stored_order(&case));

        let reached = list_reached_names(&workflow);

        let expected: BTreeSet<String> =
            case.reached_from_first.iter().cloned().collect();
        assert_eq!(reached, expected, "{}", case.description);
    }
    Ok(())
}

#[test]
fn test_create_run_property_steps_agree_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let workflow = build_case_workflow(&case, &stored_order(&case));

        let run_steps = plan_run_step_names(&workflow);

        assert_eq!(run_steps, case.run_steps, "{}", case.description);
    }
    Ok(())
}

#[test]
fn test_create_run_property_shared_table_plans_valid_cases_in_order()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let expected_steps = case.is_valid.then(|| case.order.clone());

        assert_eq!(case.run_steps, expected_steps, "{}", case.description);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_agents_in_order_property_shared_table_ignores_storage_order(
        case_position in any::<prop::sample::Index>(),
        storage_order in
            Just((0..LARGEST_CASE_AGENT_COUNT).collect::<Vec<usize>>())
                .prop_shuffle(),
    ) {
        let cases = read_shared_cases()?;
        let case = &cases[case_position.index(cases.len())];
        let kept_order: Vec<usize> = storage_order
            .into_iter()
            .filter(|position| *position < case.agents.len())
            .collect();
        let workflow = build_case_workflow(case, &kept_order);

        let names = list_names_in_order(&workflow);

        prop_assert_eq!(names, case.order.clone());
        prop_assert_eq!(validate_workflow(&workflow).is_ok(), case.is_valid);
        prop_assert_eq!(plan_run_step_names(&workflow), case.run_steps.clone());
    }
}
