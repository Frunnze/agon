use std::collections::BTreeMap;

use orchestration_core::identifiers::{WorkflowAgentId, generate_uuid};
use orchestration_core::workflow::{AgentConnection, Workflow, WorkflowAgent};

type StepIdChanges = BTreeMap<WorkflowAgentId, WorkflowAgentId>;

#[must_use]
pub fn keep_stored_step_ids(
    changed: &Workflow,
    stored: &Workflow,
) -> Workflow {
    let mut id_changes = StepIdChanges::new();
    let mut agents = Vec::new();
    for agent in &changed.agents {
        let kept_id = choose_step_id(agent, stored);
        id_changes.insert(agent.id, kept_id);
        agents.push(WorkflowAgent {
            id: kept_id,
            ..agent.clone()
        });
    }

    let mut connections = Vec::new();
    for connection in &changed.connections {
        connections.push(AgentConnection {
            from: move_step_id(&id_changes, connection.from),
            to: move_step_id(&id_changes, connection.to),
            ..connection.clone()
        });
    }

    Workflow {
        agents,
        connections,
        ..changed.clone()
    }
}

fn choose_step_id(
    changed_step: &WorkflowAgent,
    stored: &Workflow,
) -> WorkflowAgentId {
    let stored_step = stored
        .agents
        .iter()
        .find(|stored_agent| stored_agent.name == changed_step.name);
    match stored_step {
        Some(stored_agent) => stored_agent.id,
        None => WorkflowAgentId(generate_uuid()),
    }
}

fn move_step_id(
    id_changes: &StepIdChanges,
    drafted_id: WorkflowAgentId,
) -> WorkflowAgentId {
    id_changes.get(&drafted_id).copied().unwrap_or(drafted_id)
}
