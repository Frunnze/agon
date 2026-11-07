use std::collections::BTreeSet;

use crate::identifiers::WorkflowAgentId;
use crate::run::{EarlierStepRound, LoopRounds, Run, RunStep, StepStatus};
use crate::run_lifecycle::derive_run_status;
use crate::workflow::{AgentConnection, Workflow};
use crate::workflow_graph::forward_reachable_agents;

const NO_ROUNDS_TAKEN: u32 = 0;
const ONE_ROUND: u32 = 1;

pub(crate) fn find_taken_loop<'workflow>(
    workflow: &'workflow Workflow,
    finished_step: &RunStep,
) -> Option<&'workflow AgentConnection> {
    if finished_step.status != StepStatus::Done {
        return None;
    }
    let agent_id = finished_step.agent_id?;
    let outcome = finished_step.outcome.as_ref()?;
    workflow.connections.iter().find(|connection| {
        connection.is_loop()
            && connection.from == agent_id
            && connection.condition.as_ref() == Some(outcome)
    })
}

pub(crate) fn start_loop_round(
    run: &Run,
    workflow: &Workflow,
    taken_loop: &AgentConnection,
    source_name: &str,
) -> Run {
    let reset_agents = forward_reachable_agents(workflow, taken_loop.to);
    let round_start = RoundStart {
        reset_agents: &reset_agents,
        target: taken_loop.to,
        source_name,
    };
    let mut steps = Vec::new();
    for step in &run.steps {
        steps.push(reset_for_round(step, &round_start));
    }
    let target_name = name_step_of(run, taken_loop.to);
    let kept_rounds =
        forget_nested_loop_rounds(run, workflow, taken_loop, &reset_agents);
    let counted_rounds =
        count_one_more_round(&kept_rounds, source_name, &target_name);
    Run {
        status: derive_run_status(&steps),
        steps,
        loop_rounds: counted_rounds,
        ..run.clone()
    }
}

pub(crate) fn count_rounds(run: &Run, from: &str, to: &str) -> u32 {
    run.loop_rounds
        .iter()
        .find(|rounds| rounds.from == from && rounds.to == to)
        .map_or(NO_ROUNDS_TAKEN, |rounds| rounds.rounds)
}

pub(crate) fn name_step_of(run: &Run, agent_id: WorkflowAgentId) -> String {
    let step = run
        .steps
        .iter()
        .find(|step| step.agent_id == Some(agent_id));
    step.map_or_else(|| agent_id.0.to_string(), |step| step.name.clone())
}

struct RoundStart<'round> {
    reset_agents: &'round BTreeSet<WorkflowAgentId>,
    target: WorkflowAgentId,
    source_name: &'round str,
}

fn reset_for_round(step: &RunStep, round_start: &RoundStart<'_>) -> RunStep {
    let Some(agent_id) = step.agent_id else {
        return step.clone();
    };
    let is_busy = matches!(
        step.status,
        StepStatus::Running | StepStatus::WaitingForApproval
    );
    if is_busy || !round_start.reset_agents.contains(&agent_id) {
        return step.clone();
    }

    let mut earlier_rounds = step.earlier_rounds.clone();
    let is_finished =
        matches!(step.status, StepStatus::Done | StepStatus::Skipped);
    if is_finished {
        earlier_rounds.push(EarlierStepRound {
            status: step.status,
            started_at: step.started_at,
            finished_at: step.finished_at,
            result: step.result.clone(),
            outcome: step.outcome.clone(),
        });
    }
    let is_target = agent_id == round_start.target;
    let loop_source = is_target.then(|| round_start.source_name.to_owned());
    RunStep {
        runner: None,
        status: StepStatus::Waiting,
        started_at: None,
        finished_at: None,
        result: None,
        outcome: None,
        loop_source,
        earlier_rounds,
        ..step.clone()
    }
}

fn is_nested_loop(
    workflow: &Workflow,
    connection: &AgentConnection,
    taken_loop: &AgentConnection,
    reset_agents: &BTreeSet<WorkflowAgentId>,
) -> bool {
    if !connection.is_loop() || !reset_agents.contains(&connection.to) {
        return false;
    }
    if connection.to != taken_loop.to {
        return true;
    }
    let is_taken_loop = connection.from == taken_loop.from;
    let reached_from_source =
        forward_reachable_agents(workflow, connection.from);
    let reaches_taken_source = reached_from_source.contains(&taken_loop.from);
    !is_taken_loop && reaches_taken_source
}

fn forget_nested_loop_rounds(
    run: &Run,
    workflow: &Workflow,
    taken_loop: &AgentConnection,
    reset_agents: &BTreeSet<WorkflowAgentId>,
) -> Vec<LoopRounds> {
    let mut nested_loop_names = Vec::new();
    for connection in &workflow.connections {
        if is_nested_loop(workflow, connection, taken_loop, reset_agents) {
            let from = name_step_of(run, connection.from);
            let to = name_step_of(run, connection.to);
            nested_loop_names.push((from, to));
        }
    }
    let mut kept_rounds = Vec::new();
    for rounds in &run.loop_rounds {
        let is_nested = nested_loop_names
            .iter()
            .any(|(from, to)| rounds.from == *from && rounds.to == *to);
        if !is_nested {
            kept_rounds.push(rounds.clone());
        }
    }
    kept_rounds
}

fn count_one_more_round(
    earlier_rounds: &[LoopRounds],
    from: &str,
    to: &str,
) -> Vec<LoopRounds> {
    let mut loop_rounds = Vec::new();
    let mut is_counted = false;
    for rounds in earlier_rounds {
        let is_this_loop = rounds.from == from && rounds.to == to;
        if is_this_loop {
            loop_rounds.push(LoopRounds {
                rounds: rounds.rounds.saturating_add(ONE_ROUND),
                ..rounds.clone()
            });
            is_counted = true;
        } else {
            loop_rounds.push(rounds.clone());
        }
    }
    if !is_counted {
        loop_rounds.push(LoopRounds {
            from: from.to_owned(),
            to: to.to_owned(),
            rounds: ONE_ROUND,
        });
    }
    loop_rounds
}
