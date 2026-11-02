use chrono::{DateTime, Utc};
use orchestration_core::identifiers::WorkflowId;
use orchestration_core::run::{Run, RunStatus, StepStatus};
use orchestration_core::run_lifecycle::{RunProblem, create_run};
use orchestration_core::task::{Task, TaskDoer};
use orchestration_core::workflow::{AgentKind, Workflow};
use orchestration_core::workflow_graph::{WorkflowProblem, agents_in_order};
use proptest::option;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::{
    example_task, one_agent_doer, ordinary_timestamp, task_with_doer,
    workflow_doer,
};
use crate::run_fixtures::{RUN_NUMBER, run_identifier, starter};
use crate::workflow_strategies::{
    acyclic_workflow, arbitrary_workflow, workflow_identifier,
    workflow_with_cycle,
};

fn create_test_run(
    task: &Task,
    workflow: Option<&Workflow>,
    started_at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    create_run(
        task,
        workflow,
        RUN_NUMBER,
        run_identifier(),
        starter(),
        started_at,
    )
}

fn workflow_task(workflow_id: WorkflowId) -> impl Strategy<Value = Task> {
    task_with_doer(workflow_doer(workflow_id))
}

#[test]
fn test_create_run_names_the_single_step_after_the_agent() {
    let expected_names = [
        (AgentKind::ClaudeCode, "claude-code"),
        (AgentKind::Codex, "codex"),
        (AgentKind::GeminiCli, "gemini-cli"),
    ];

    for (agent, expected_name) in expected_names {
        let task = Task {
            doer: TaskDoer::OneAgent { agent },
            ..example_task()
        };
        let run = create_test_run(&task, None, DateTime::UNIX_EPOCH);
        let step_names: Option<Vec<String>> = run
            .ok()
            .map(|run| run.steps.into_iter().map(|step| step.name).collect());
        assert_eq!(step_names, Some(vec![expected_name.to_owned()]));
    }
}

proptest! {
    #[test]
    fn test_create_run_property_starts_queued_with_waiting_steps(
        task in task_with_doer(one_agent_doer()),
        started_at in ordinary_timestamp(),
    ) {
        let run = create_test_run(&task, None, started_at);

        prop_assert!(run.is_ok());
        if let Ok(run) = run {
            prop_assert_eq!(run.status, RunStatus::Queued);
            prop_assert_eq!(run.task_id, task.id);
            prop_assert_eq!(run.number, RUN_NUMBER);
            prop_assert_eq!(run.started_at, started_at);
            prop_assert_eq!(run.started_by, starter());
            prop_assert_eq!(run.worktree_branch, None);
            prop_assert_eq!(run.finished_at, None);
            prop_assert_eq!(run.steps.len(), 1);
            prop_assert!(run.log.is_empty() && run.chat.is_empty());
        }
    }

    #[test]
    fn test_create_run_property_workflow_steps_follow_agent_order(
        workflow in acyclic_workflow(),
        task in workflow_task(workflow_identifier()),
        started_at in ordinary_timestamp(),
    ) {
        let run = create_test_run(&task, Some(&workflow), started_at);

        let ordered_names: Vec<String> = agents_in_order(&workflow)
            .iter()
            .map(|agent| agent.name.clone())
            .collect();
        prop_assert!(run.is_ok());
        if let Ok(run) = run {
            let step_names: Vec<String> =
                run.steps.iter().map(|step| step.name.clone()).collect();
            prop_assert_eq!(step_names, ordered_names);
            for step in &run.steps {
                prop_assert_eq!(step.status, StepStatus::Waiting);
                prop_assert!(step.agent_id.is_some());
            }
        }
    }

    #[test]
    fn test_create_run_property_rejects_a_mismatched_workflow(
        workflow in acyclic_workflow(),
        other_number in any::<u128>(),
        task in workflow_task(workflow_identifier()),
        one_agent_task in task_with_doer(one_agent_doer()),
        started_at in ordinary_timestamp(),
    ) {
        let other_id = WorkflowId(Uuid::from_u128(other_number));
        let other_workflow = Workflow { id: other_id, ..workflow.clone() };

        let missing = create_test_run(&task, None, started_at);
        let wrong = create_test_run(&task, Some(&other_workflow), started_at);
        let unexpected =
            create_test_run(&one_agent_task, Some(&workflow), started_at);

        let expected_id = workflow_identifier();
        prop_assert_eq!(
            missing,
            Err(RunProblem::MissingWorkflow { workflow_id: expected_id })
        );
        if other_id != expected_id {
            prop_assert_eq!(
                wrong,
                Err(RunProblem::WrongWorkflow {
                    expected: expected_id,
                    given: other_id,
                })
            );
        }
        prop_assert_eq!(unexpected, Err(RunProblem::UnexpectedWorkflow));
    }

    #[test]
    fn test_create_run_property_rejects_an_invalid_workflow(
        workflow in workflow_with_cycle(),
        task in workflow_task(workflow_identifier()),
        started_at in ordinary_timestamp(),
    ) {
        let run = create_test_run(&task, Some(&workflow), started_at);

        prop_assert_eq!(
            run,
            Err(RunProblem::InvalidWorkflow(WorkflowProblem::Cycle))
        );
    }

    #[test]
    fn test_create_run_fuzz_arbitrary_input_gives_run_or_problem(
        workflow in option::of(arbitrary_workflow()),
        task in prop_oneof![
            task_with_doer(one_agent_doer()),
            workflow_task(workflow_identifier()),
        ],
        started_at in ordinary_timestamp(),
    ) {
        let run = create_test_run(&task, workflow.as_ref(), started_at);

        if let Ok(run) = run {
            prop_assert!(!run.steps.is_empty());
            prop_assert_eq!(run.status, RunStatus::Queued);
        }
    }
}
