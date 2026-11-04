use orchestration_core::library::{Rule, Skill, SkillChange};
use orchestration_core::task::Task;
use orchestration_core::workflow::{Workflow, WorkflowAgent};
use orchestration_security::sealing::{WorkspaceKey, open_text, seal_text};

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
    let mut sealed_history = Vec::new();
    for change in &skill.history {
        let replaced = &change.replaced_instructions;
        sealed_history.push(SkillChange {
            replaced_instructions: seal_text(workspace_key, replaced)?,
            ..change.clone()
        });
    }
    Ok(Skill {
        instructions: seal_text(workspace_key, &skill.instructions)?,
        history: sealed_history,
        ..skill.clone()
    })
}

pub fn open_skill(
    keyring: &WorkspaceKeyring,
    skill: &Skill,
) -> Result<Skill, NodeError> {
    let mut opened_history = Vec::new();
    for change in &skill.history {
        let replaced = &change.replaced_instructions;
        opened_history.push(SkillChange {
            replaced_instructions: keyring.open_text(replaced)?,
            ..change.clone()
        });
    }
    Ok(Skill {
        instructions: keyring.open_text(&skill.instructions)?,
        history: opened_history,
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

pub fn reseal_workflow(
    workspace_key: &WorkspaceKey,
    workflow: &Workflow,
    stored_workflow: &Workflow,
) -> Result<Workflow, NodeError> {
    let mut sealed_agents = Vec::new();
    for agent in &workflow.agents {
        let task = reseal_step_task(workspace_key, agent, stored_workflow)?;
        sealed_agents.push(WorkflowAgent {
            task,
            ..agent.clone()
        });
    }
    Ok(Workflow {
        agents: sealed_agents,
        ..workflow.clone()
    })
}

fn reseal_step_task(
    workspace_key: &WorkspaceKey,
    agent: &WorkflowAgent,
    stored_workflow: &Workflow,
) -> Result<String, NodeError> {
    let stored_agent = stored_workflow
        .agents
        .iter()
        .find(|stored_agent| stored_agent.id == agent.id);
    if let Some(stored_agent) = stored_agent
        && seals_same_text(workspace_key, &stored_agent.task, &agent.task)
    {
        return Ok(stored_agent.task.clone());
    }
    Ok(seal_text(workspace_key, &agent.task)?)
}

fn seals_same_text(
    workspace_key: &WorkspaceKey,
    sealed_text: &str,
    plain_text: &str,
) -> bool {
    match open_text(workspace_key, sealed_text) {
        Ok(opened_text) => opened_text == plain_text,
        Err(_) => false,
    }
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
