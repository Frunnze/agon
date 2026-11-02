use orchestration_core::library::{Rule, Skill};
use orchestration_core::task::Task;
use orchestration_core::workflow::{Workflow, WorkflowAgent};
use orchestration_security::sealing::{WorkspaceKey, seal_text};

use super::workspace_keyring::WorkspaceKeyring;
use crate::node_error::NodeError;

pub fn seal_task(
    workspace_key: &WorkspaceKey,
    task: &Task,
) -> Result<Task, NodeError> {
    Ok(Task {
        details: seal_text(workspace_key, &task.details)?,
        ..task.clone()
    })
}

pub fn open_task(
    keyring: &WorkspaceKeyring,
    task: &Task,
) -> Result<Task, NodeError> {
    Ok(Task {
        details: keyring.open_text(&task.details)?,
        ..task.clone()
    })
}

pub fn seal_skill(
    workspace_key: &WorkspaceKey,
    skill: &Skill,
) -> Result<Skill, NodeError> {
    Ok(Skill {
        instructions: seal_text(workspace_key, &skill.instructions)?,
        ..skill.clone()
    })
}

pub fn open_skill(
    keyring: &WorkspaceKeyring,
    skill: &Skill,
) -> Result<Skill, NodeError> {
    Ok(Skill {
        instructions: keyring.open_text(&skill.instructions)?,
        ..skill.clone()
    })
}

pub fn seal_rule(
    workspace_key: &WorkspaceKey,
    rule: &Rule,
) -> Result<Rule, NodeError> {
    Ok(Rule {
        details: seal_text(workspace_key, &rule.details)?,
        ..rule.clone()
    })
}

pub fn open_rule(
    keyring: &WorkspaceKeyring,
    rule: &Rule,
) -> Result<Rule, NodeError> {
    Ok(Rule {
        details: keyring.open_text(&rule.details)?,
        ..rule.clone()
    })
}

pub fn seal_workflow(
    workspace_key: &WorkspaceKey,
    workflow: &Workflow,
) -> Result<Workflow, NodeError> {
    let mut sealed_agents = Vec::new();
    for agent in &workflow.agents {
        sealed_agents.push(WorkflowAgent {
            task: seal_text(workspace_key, &agent.task)?,
            ..agent.clone()
        });
    }
    Ok(Workflow {
        agents: sealed_agents,
        ..workflow.clone()
    })
}

pub fn open_workflow(
    keyring: &WorkspaceKeyring,
    workflow: &Workflow,
) -> Result<Workflow, NodeError> {
    let mut opened_agents = Vec::new();
    for agent in &workflow.agents {
        opened_agents.push(WorkflowAgent {
            task: keyring.open_text(&agent.task)?,
            ..agent.clone()
        });
    }
    Ok(Workflow {
        agents: opened_agents,
        ..workflow.clone()
    })
}
