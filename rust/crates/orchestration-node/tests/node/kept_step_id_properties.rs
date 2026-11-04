use std::collections::{BTreeMap, BTreeSet};

use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{WorkflowAgentId, WorkflowId};
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{
    AgentConnection, AgentKind, CanvasPosition, StepKind, Workflow,
    WorkflowAgent,
};
use orchestration_node::item_drafting::keep_stored_step_ids;
use proptest::collection::{btree_set, vec};
use proptest::prelude::*;
use uuid::Uuid;

const PROPERTY_CASES: u32 = 128;
const STORED_NAME_POOL: u128 = 6;
const MAXIMUM_STORED_STEPS: usize = 6;
const NEW_NAME_POOL: usize = 4;
const MAXIMUM_CONNECTIONS: usize = 8;
const SMALL_ID_RANGE: u128 = 12;

type NamedConnection = (String, String, Option<String>, Option<u32>);

fn step(id: WorkflowAgentId, name: &str) -> WorkflowAgent {
    WorkflowAgent {
        id,
        name: name.to_owned(),
        step_kind: StepKind::Agent,
        kind: Some(AgentKind::ClaudeCode),
        task: format!("Do the {name} step"),
        runs_on: RunnerTarget::AnyFreeRunner,
        skills: Vec::new(),
        uses_automatic_skills: false,
        approval_policy: Some(ApprovalPolicy::NeverAsk),
        position: CanvasPosition {
            horizontal: 0.0,
            vertical: 0.0,
        },
    }
}

fn workflow_of(
    agents: Vec<WorkflowAgent>,
    connections: Vec<AgentConnection>,
) -> Workflow {
    Workflow {
        id: WorkflowId(Uuid::nil()),
        name: "poems-pipeline".to_owned(),
        availability: WorkspaceScope::AllWorkspaces,
        agents,
        connections,
        signature: None,
    }
}

fn distinct_small_agent_ids(
    count: usize,
) -> impl Strategy<Value = Vec<WorkflowAgentId>> {
    let every_number: Vec<u128> = (0..SMALL_ID_RANGE).collect();
    Just(every_number).prop_shuffle().prop_map(move |numbers| {
        let mut ids = Vec::new();
        for number in numbers.into_iter().take(count) {
            ids.push(WorkflowAgentId(Uuid::from_u128(number)));
        }
        ids
    })
}

fn stored_workflow_strategy() -> impl Strategy<Value = Workflow> {
    btree_set(0..STORED_NAME_POOL, 1..=MAXIMUM_STORED_STEPS).prop_map(
        |name_numbers| {
            let mut agents = Vec::new();
            for number in name_numbers {
                let id = WorkflowAgentId(Uuid::from_u128(number));
                agents.push(step(id, &format!("kept-{number}")));
            }
            workflow_of(agents, Vec::new())
        },
    )
}

fn changed_names_strategy(stored: &Workflow) -> BoxedStrategy<Vec<String>> {
    let stored_names: Vec<String> = stored
        .agents
        .iter()
        .map(|agent| agent.name.clone())
        .collect();
    let stored_count = stored_names.len();
    let kept_names =
        proptest::sample::subsequence(stored_names, 0..=stored_count);
    let new_names = btree_set(0..NEW_NAME_POOL, 0..=NEW_NAME_POOL);
    (kept_names, new_names)
        .prop_filter("a workflow has a step", |(kept, new)| {
            !kept.is_empty() || !new.is_empty()
        })
        .prop_map(|(kept, new)| {
            let mut names = kept;
            for number in new {
                names.push(format!("new-{number}"));
            }
            names
        })
        .boxed()
}

fn changed_workflow_strategy(
    names: Vec<String>,
) -> impl Strategy<Value = Workflow> {
    let step_count = names.len();
    let ids = distinct_small_agent_ids(step_count);
    let connections = vec(
        (0..step_count, 0..step_count, any::<bool>(), any::<bool>()),
        0..MAXIMUM_CONNECTIONS,
    );
    (ids, connections).prop_map(move |(ids, planned_connections)| {
        let mut agents = Vec::new();
        for (index, name) in names.iter().enumerate() {
            agents.push(step(ids[index], name));
        }
        let mut connections = Vec::new();
        for (from, to, has_condition, is_loop) in planned_connections {
            connections.push(AgentConnection {
                from: agents[from].id,
                to: agents[to].id,
                condition: has_condition.then(|| "approved".to_owned()),
                round_limit: is_loop.then_some(2),
            });
        }
        workflow_of(agents, connections)
    })
}

fn change_strategy() -> impl Strategy<Value = (Workflow, Workflow)> {
    stored_workflow_strategy().prop_flat_map(|stored| {
        let kept_stored = stored.clone();
        changed_names_strategy(&stored)
            .prop_flat_map(changed_workflow_strategy)
            .prop_map(move |changed| (kept_stored.clone(), changed))
    })
}

fn ids_by_name(workflow: &Workflow) -> BTreeMap<String, WorkflowAgentId> {
    let mut ids = BTreeMap::new();
    for agent in &workflow.agents {
        ids.insert(agent.name.clone(), agent.id);
    }
    ids
}

fn name_connections(workflow: &Workflow) -> Option<Vec<NamedConnection>> {
    let mut names_by_id = BTreeMap::new();
    for agent in &workflow.agents {
        names_by_id.insert(agent.id, agent.name.clone());
    }
    let mut named = Vec::new();
    for connection in &workflow.connections {
        let from_name = names_by_id.get(&connection.from)?.clone();
        let to_name = names_by_id.get(&connection.to)?.clone();
        named.push((
            from_name,
            to_name,
            connection.condition.clone(),
            connection.round_limit,
        ));
    }
    Some(named)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROPERTY_CASES))]

    #[test]
    fn test_keep_stored_step_ids_property_kept_names_keep_their_ids(
        (stored, changed) in change_strategy(),
    ) {
        let kept = keep_stored_step_ids(&changed, &stored);

        let stored_ids = ids_by_name(&stored);
        for agent in &kept.agents {
            if let Some(stored_id) = stored_ids.get(&agent.name) {
                prop_assert_eq!(agent.id, *stored_id);
            }
        }
    }

    #[test]
    fn test_keep_stored_step_ids_property_only_new_steps_get_new_ids(
        (stored, changed) in change_strategy(),
    ) {
        let kept = keep_stored_step_ids(&changed, &stored);

        let stored_names = ids_by_name(&stored);
        let stored_ids: BTreeSet<WorkflowAgentId> =
            stored_names.values().copied().collect();
        let mut seen_ids = BTreeSet::new();
        for agent in &kept.agents {
            prop_assert!(seen_ids.insert(agent.id));
            if !stored_names.contains_key(&agent.name) {
                prop_assert!(!stored_ids.contains(&agent.id));
            }
        }
    }

    #[test]
    fn test_keep_stored_step_ids_property_connections_join_the_same_steps(
        (stored, changed) in change_strategy(),
    ) {
        let kept = keep_stored_step_ids(&changed, &stored);

        let drafted_connections = name_connections(&changed);
        prop_assert!(drafted_connections.is_some());
        prop_assert_eq!(name_connections(&kept), drafted_connections);
        prop_assert_eq!(kept.connections.len(), changed.connections.len());
    }

    #[test]
    fn test_keep_stored_step_ids_property_changes_nothing_but_ids(
        (stored, changed) in change_strategy(),
    ) {
        let kept = keep_stored_step_ids(&changed, &stored);

        prop_assert_eq!(kept.agents.len(), changed.agents.len());
        for (kept_agent, changed_agent) in
            kept.agents.iter().zip(&changed.agents)
        {
            let same_but_id = WorkflowAgent {
                id: kept_agent.id,
                ..changed_agent.clone()
            };
            prop_assert_eq!(kept_agent, &same_but_id);
        }
        prop_assert_eq!(&kept.name, &changed.name);
    }
}
