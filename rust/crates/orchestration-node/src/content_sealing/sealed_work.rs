use orchestration_api::work::{RunAssignment, RunEvent};
use orchestration_core::run::{
    ChatMessage, EarlierStepRound, LogLine, Run, RunStep,
};
use orchestration_security::sealing::{WorkspaceKey, seal_text};

use super::sealed_catalog::{open_rule, open_skill, open_task, open_workflow};
use super::workspace_keyring::WorkspaceKeyring;
use crate::node_error::NodeError;

pub fn seal_chat_message(
    workspace_key: &WorkspaceKey,
    message: &ChatMessage,
) -> Result<ChatMessage, NodeError> {
    Ok(ChatMessage {
        text: seal_text(workspace_key, &message.text)?,
        ..message.clone()
    })
}

pub fn open_chat_message(
    keyring: &WorkspaceKeyring,
    message: &ChatMessage,
) -> Result<ChatMessage, NodeError> {
    Ok(ChatMessage {
        text: keyring.open_text(&message.text)?,
        ..message.clone()
    })
}

pub fn seal_log_line(
    workspace_key: &WorkspaceKey,
    line: &LogLine,
) -> Result<LogLine, NodeError> {
    Ok(LogLine {
        text: seal_text(workspace_key, &line.text)?,
        ..line.clone()
    })
}

pub fn open_log_line(
    keyring: &WorkspaceKeyring,
    line: &LogLine,
) -> Result<LogLine, NodeError> {
    Ok(LogLine {
        text: keyring.open_text(&line.text)?,
        ..line.clone()
    })
}

pub fn open_run(
    keyring: &WorkspaceKeyring,
    run: &Run,
) -> Result<Run, NodeError> {
    let mut opened_log = Vec::new();
    for line in &run.log {
        opened_log.push(open_log_line(keyring, line)?);
    }
    let mut opened_chat = Vec::new();
    for message in &run.chat {
        opened_chat.push(open_chat_message(keyring, message)?);
    }
    let mut opened_steps = Vec::new();
    for step in &run.steps {
        opened_steps.push(open_step_result(keyring, step)?);
    }
    Ok(Run {
        steps: opened_steps,
        log: opened_log,
        chat: opened_chat,
        ..run.clone()
    })
}

fn open_step_result(
    keyring: &WorkspaceKeyring,
    step: &RunStep,
) -> Result<RunStep, NodeError> {
    let mut opened_rounds = Vec::new();
    for round in &step.earlier_rounds {
        opened_rounds.push(EarlierStepRound {
            result: open_optional_text(keyring, round.result.as_ref())?,
            ..round.clone()
        });
    }
    Ok(RunStep {
        result: open_optional_text(keyring, step.result.as_ref())?,
        earlier_rounds: opened_rounds,
        ..step.clone()
    })
}

fn open_optional_text(
    keyring: &WorkspaceKeyring,
    sealed_text: Option<&String>,
) -> Result<Option<String>, NodeError> {
    let Some(sealed_text) = sealed_text else {
        return Ok(None);
    };
    Ok(Some(keyring.open_text(sealed_text)?))
}

pub fn seal_run_event(
    workspace_key: &WorkspaceKey,
    event: &RunEvent,
) -> Result<RunEvent, NodeError> {
    let sealed_event = match event {
        RunEvent::LogAppended { line } => RunEvent::LogAppended {
            line: seal_log_line(workspace_key, line)?,
        },
        RunEvent::ChatAppended { message } => RunEvent::ChatAppended {
            message: seal_chat_message(workspace_key, message)?,
        },
        RunEvent::StepResultRecorded {
            step_name,
            result,
            outcome,
        } => RunEvent::StepResultRecorded {
            step_name: step_name.clone(),
            result: seal_text(workspace_key, result)?,
            outcome: outcome.clone(),
        },
        other_event => other_event.clone(),
    };
    Ok(sealed_event)
}

pub fn open_run_assignment(
    keyring: &WorkspaceKeyring,
    assignment: &RunAssignment,
) -> Result<RunAssignment, NodeError> {
    let opened_workflow = match &assignment.workflow {
        Some(workflow) => Some(open_workflow(keyring, workflow)?),
        None => None,
    };
    let mut opened_skills = Vec::new();
    for skill in &assignment.skills {
        opened_skills.push(open_skill(keyring, skill)?);
    }
    let mut opened_rules = Vec::new();
    for rule in &assignment.rules {
        opened_rules.push(open_rule(keyring, rule)?);
    }
    Ok(RunAssignment {
        step_name: assignment.step_name.clone(),
        run: open_run(keyring, &assignment.run)?,
        task: open_task(keyring, &assignment.task)?,
        workspace_id: assignment.workspace_id,
        project: assignment.project.clone(),
        workflow: opened_workflow,
        skills: opened_skills,
        rules: opened_rules,
        follow_up: assignment.follow_up,
    })
}
