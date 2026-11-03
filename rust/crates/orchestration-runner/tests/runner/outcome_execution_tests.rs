use std::sync::Arc;

use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::WorkflowId;
use orchestration_core::run::StepStatus;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::{AgentConnection, StepKind, Workflow};
use orchestration_runner::run_executor::RunOutcome;
use orchestration_runner::step_plan::{AssignmentProblem, plan_assigned_step};
use proptest::prelude::*;
use tokio::runtime::Runtime;
use uuid::Uuid;

use crate::assignments::{assignment_for, task_for};
use crate::event_queries::{failures, step_statuses};
use crate::executor_support::{RUN_NUMBER, execute_with_git_pusher};
use crate::fake_agent::{
    local_configuration, prepare_agent_folders, read_prompt,
};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, to_case_error};
use crate::workflows::{
    WORKFLOW_NUMBER, WorkflowShape, agent_id, agent_name, build_workflow,
};

const CHOICES: [&str; 2] = ["approved", "changes"];

#[derive(Debug)]
struct OutcomeRun {
    prompt: String,
    outcome: RunOutcome,
    events: Vec<RunEvent>,
}

fn review_workflow(review_task: &str) -> Workflow {
    let shape = WorkflowShape {
        agent_count: 2,
        connections: Vec::new(),
        positions: vec![(0, 0), (0, 1)],
        failing_agents: vec![false, false],
    };
    let mut workflow = build_workflow(&shape);
    review_task.clone_into(&mut workflow.agents[0].task);
    workflow.connections = vec![
        AgentConnection {
            condition: Some(CHOICES[0].to_owned()),
            ..AgentConnection::plain(agent_id(0), agent_id(1))
        },
        AgentConnection {
            condition: Some(CHOICES[1].to_owned()),
            ..AgentConnection::plain(agent_id(0), agent_id(1))
        },
    ];
    workflow
}

fn review_doer() -> TaskDoer {
    TaskDoer::Workflow {
        workflow_id: WorkflowId(Uuid::from_u128(WORKFLOW_NUMBER)),
    }
}

fn execute_review(review_task: &str) -> TestResult<OutcomeRun> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let task = task_for(RUN_NUMBER, "Review the change", review_doer());
    let workflow = review_workflow(review_task);
    let mut assignment =
        assignment_for(task, Some(workflow), Vec::new(), RUN_NUMBER)?;
    assignment.step_name = agent_name(0);
    let run_id = assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));
    let runtime = Runtime::new()?;

    let outcome = runtime.block_on(execute_with_git_pusher(
        &server,
        &configuration,
        assignment,
    ))?;
    Ok(OutcomeRun {
        prompt: read_prompt(&folders, &agent_name(0))?,
        outcome,
        events: server.events_of(run_id),
    })
}

fn reported_outcomes(events: &[RunEvent]) -> Vec<Option<String>> {
    let mut outcomes = Vec::new();
    for event in events {
        if let RunEvent::StepResultRecorded { outcome, .. } = event {
            outcomes.push(outcome.clone());
        }
    }
    outcomes
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_execute_property_reports_the_outcome_the_agent_named(
        chosen in 0_usize..2,
    ) {
        let review_task =
            format!("step-0\nplease-outcome-{}", CHOICES[chosen]);

        let run = execute_review(&review_task).map_err(to_case_error)?;

        prop_assert!(run.prompt.contains("OUTCOME: <name>"));
        prop_assert!(run.prompt.contains("one of: approved, changes"));
        prop_assert_eq!(run.outcome, RunOutcome::Finished);
        let expected = vec![Some(CHOICES[chosen].to_owned())];
        prop_assert_eq!(reported_outcomes(&run.events), expected);
    }
}

#[test]
fn a_step_without_an_outcome_fails_naming_the_choices() {
    let run = execute_review("step-0");

    let Ok(run) = run else {
        panic!("the step runs: {run:?}");
    };
    assert_eq!(run.outcome, RunOutcome::Failed);
    let reasons: Vec<String> = failures(&run.events)
        .into_iter()
        .map(|failure| failure.reason)
        .collect();
    let [reason] = reasons.as_slice() else {
        panic!("one failure is reported: {reasons:?}");
    };
    assert!(reason.contains("OUTCOME: <name>"), "{reason}");
    assert!(reason.contains("approved, changes"), "{reason}");
    let last_status = step_statuses(&run.events).pop();
    assert_eq!(last_status, Some((agent_name(0), StepStatus::Failed)));
    assert_eq!(reported_outcomes(&run.events), Vec::<Option<String>>::new());
}

#[test]
fn a_runner_refuses_to_plan_a_person_step() {
    let task = task_for(RUN_NUMBER, "Review the change", review_doer());
    let mut workflow = review_workflow("Approve it?");
    workflow.agents[0].step_kind = StepKind::Person;
    let assignment = assignment_for(task, Some(workflow), Vec::new(), 1);
    let Ok(mut assignment) = assignment else {
        panic!("the assignment is built");
    };
    assignment.step_name = agent_name(0);

    let planned = plan_assigned_step(&assignment);

    assert_eq!(planned, Err(AssignmentProblem::PersonStep(agent_name(0))));
}
