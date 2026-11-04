use chrono::DateTime;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::run::{Run, RunStep, StepStatus};
use orchestration_core::run_routing::advance_after_step;
use orchestration_core::workflow::{
    AgentConnection, CanvasPosition, StepKind, Workflow, WorkflowAgent,
};

use crate::run_fixtures::run_with_steps;
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

pub fn routing_agent(number: u128, step_kind: StepKind) -> WorkflowAgent {
    WorkflowAgent {
        id: agent_identifier(number),
        name: format!("step-{number}"),
        step_kind,
        kind: None,
        task: String::new(),
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

pub fn connect(
    from: u128,
    to: u128,
    condition: Option<&str>,
    round_limit: Option<u32>,
) -> AgentConnection {
    AgentConnection {
        from: agent_identifier(from),
        to: agent_identifier(to),
        condition: condition.map(str::to_owned),
        round_limit,
    }
}

pub fn routing_workflow(
    agent_count: u128,
    connections: Vec<AgentConnection>,
) -> Workflow {
    let mut agents = Vec::new();
    for number in 0..agent_count {
        agents.push(routing_agent(number, StepKind::Agent));
    }
    workflow_from_parts(agents, connections)
}

pub fn fresh_run(workflow: &Workflow) -> Run {
    let mut steps = Vec::new();
    for agent in &workflow.agents {
        steps.push(RunStep {
            name: agent.name.clone(),
            agent_id: Some(agent.id),
            runner: None,
            status: StepStatus::Waiting,
            started_at: None,
            finished_at: None,
            result: None,
            outcome: None,
            loop_source: None,
            earlier_rounds: Vec::new(),
        });
    }
    run_with_steps(steps)
}

pub fn step_named<'run>(run: &'run Run, step_name: &str) -> &'run RunStep {
    let found = run.steps.iter().find(|step| step.name == step_name);
    found.unwrap_or(&run.steps[0])
}

pub fn finish_step(
    run: &Run,
    workflow: &Workflow,
    step_name: &str,
    outcome: Option<&str>,
) -> Run {
    let mut finished = run.clone();
    for step in &mut finished.steps {
        if step.name == step_name {
            step.status = StepStatus::Done;
            step.result = Some(format!("result of {step_name}"));
            step.outcome = outcome.map(str::to_owned);
        }
    }
    advance_after_step(&finished, workflow, step_name, DateTime::UNIX_EPOCH)
}
