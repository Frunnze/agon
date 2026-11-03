use chrono::{DateTime, Utc};

use crate::identifiers::WorkflowAgentId;
use crate::loop_rounds::{
    count_rounds, find_taken_loop, name_step_of, start_loop_round,
};
use crate::run::{Run, RunNote, RunStatus, RunStep, StepStatus};
use crate::run_lifecycle::{RunProblem, derive_run_status, is_run_finished};
use crate::step_outcomes::list_step_choices;
use crate::workflow::{AgentConnection, StepKind, Workflow};
use crate::workflow_graph::{find_agent_by_id, forward_connections};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum InputState {
    Pending,
    NoneTaken,
    Taken,
}

#[must_use]
pub fn is_step_claimable(
    run: &Run,
    step: &RunStep,
    workflow: Option<&Workflow>,
) -> bool {
    let is_unclaimed =
        step.status == StepStatus::Waiting && step.runner.is_none();
    if !is_unclaimed {
        return false;
    }
    let (Some(agent_id), Some(workflow)) = (step.agent_id, workflow) else {
        return true;
    };
    let is_person_step = find_agent_by_id(workflow, agent_id)
        .is_some_and(|agent| agent.step_kind == StepKind::Person);
    let input_state = read_input_state(run, workflow, agent_id);
    !is_person_step && input_state == InputState::Taken
}

#[must_use]
pub fn settle_waiting_steps(
    run: &Run,
    workflow: &Workflow,
    at: DateTime<Utc>,
) -> Run {
    if is_run_finished(run.status) {
        return run.clone();
    }
    let mut settled = run.clone();
    while let Some((index, status)) = find_settling_step(&settled, workflow) {
        let step = &settled.steps[index];
        let settled_step = if status == StepStatus::Skipped {
            RunStep {
                status,
                finished_at: Some(at),
                ..step.clone()
            }
        } else {
            RunStep {
                status,
                started_at: Some(at),
                ..step.clone()
            }
        };
        settled.steps[index] = settled_step;
    }
    let status = derive_run_status(&settled.steps);
    let finished_at = is_run_finished(status).then_some(at);
    Run {
        status,
        finished_at,
        ..settled
    }
}

#[must_use]
pub fn advance_after_step(
    run: &Run,
    workflow: &Workflow,
    step_name: &str,
    at: DateTime<Utc>,
) -> Run {
    let taken_loop = run
        .steps
        .iter()
        .find(|step| step.name == step_name)
        .and_then(|step| find_taken_loop(workflow, step));
    let Some(taken_loop) = taken_loop else {
        return settle_waiting_steps(run, workflow, at);
    };

    let target_name = name_step_of(run, taken_loop.to);
    let rounds_taken = count_rounds(run, step_name, &target_name);
    let round_limit = taken_loop.round_limit.unwrap_or_default();
    if rounds_taken < round_limit {
        let looped = start_loop_round(run, workflow, taken_loop, step_name);
        return settle_waiting_steps(&looped, workflow, at);
    }

    let limit_note = format!(
        "{step_name} → {target_name} reached its limit of \
         {round_limit} rounds"
    );
    let noted = add_note(run, &limit_note, at);
    let settled = settle_waiting_steps(&noted, workflow, at);
    if settled.status != RunStatus::Done {
        return settled;
    }
    let ending_note =
        format!("Nothing else follows {step_name}, so the run finished");
    add_note(&settled, &ending_note, at)
}

pub fn advance_newly_done_steps(
    before: &Run,
    after: &Run,
    workflow: &Workflow,
    at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    let mut newly_done_names = Vec::new();
    for step in &after.steps {
        let was_done = before.steps.iter().any(|earlier| {
            earlier.name == step.name && earlier.status == StepStatus::Done
        });
        if step.status == StepStatus::Done && !was_done {
            require_known_outcome(workflow, step)?;
            newly_done_names.push(step.name.clone());
        }
    }
    let mut advanced = after.clone();
    for step_name in &newly_done_names {
        advanced = advance_after_step(&advanced, workflow, step_name, at);
    }
    Ok(advanced)
}

fn require_known_outcome(
    workflow: &Workflow,
    step: &RunStep,
) -> Result<(), RunProblem> {
    let Some(agent_id) = step.agent_id else {
        return Ok(());
    };
    let choices = list_step_choices(workflow, agent_id);
    if choices.is_empty() {
        return Ok(());
    }
    let is_known = step
        .outcome
        .as_ref()
        .is_some_and(|outcome| choices.contains(outcome));
    if is_known {
        return Ok(());
    }
    Err(RunProblem::UnknownOutcome {
        step_name: step.name.clone(),
        choices,
    })
}

fn find_settling_step(
    run: &Run,
    workflow: &Workflow,
) -> Option<(usize, StepStatus)> {
    for (index, step) in run.steps.iter().enumerate() {
        let is_unclaimed =
            step.status == StepStatus::Waiting && step.runner.is_none();
        let Some(agent_id) = step.agent_id else {
            continue;
        };
        let Some(agent) = find_agent_by_id(workflow, agent_id) else {
            continue;
        };
        if !is_unclaimed {
            continue;
        }
        let input_state = read_input_state(run, workflow, agent_id);
        if input_state == InputState::NoneTaken {
            return Some((index, StepStatus::Skipped));
        }
        let is_person_step = agent.step_kind == StepKind::Person;
        if input_state == InputState::Taken && is_person_step {
            return Some((index, StepStatus::WaitingForPerson));
        }
    }
    None
}

fn read_input_state(
    run: &Run,
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> InputState {
    let incoming: Vec<&AgentConnection> = forward_connections(workflow)
        .into_iter()
        .filter(|connection| connection.to == agent_id)
        .collect();
    if incoming.is_empty() {
        return InputState::Taken;
    }
    let mut is_any_taken = false;
    for connection in incoming {
        let source = run
            .steps
            .iter()
            .find(|step| step.agent_id == Some(connection.from));
        let Some(source) = source else {
            continue;
        };
        match source.status {
            StepStatus::Done => {
                if is_connection_taken(connection, source) {
                    is_any_taken = true;
                }
            }
            StepStatus::Skipped => {}
            _ => return InputState::Pending,
        }
    }
    if is_any_taken {
        return InputState::Taken;
    }
    InputState::NoneTaken
}

fn is_connection_taken(
    connection: &AgentConnection,
    source: &RunStep,
) -> bool {
    match &connection.condition {
        None => true,
        Some(condition) => source.outcome.as_ref() == Some(condition),
    }
}

fn add_note(run: &Run, text: &str, at: DateTime<Utc>) -> Run {
    let mut notes = run.notes.clone();
    notes.push(RunNote {
        at,
        text: text.to_owned(),
    });
    Run {
        notes,
        ..run.clone()
    }
}
