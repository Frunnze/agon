use std::collections::BTreeSet;

use orchestration_core::device::RunnerLink;
use orchestration_core::run::{Run, RunStatus, StepStatus};
use orchestration_core::run_lifecycle::{RunProblem, derive_run_status};
use orchestration_core::task::{Task, TaskDoer};
use orchestration_core::workflow_graph::agents_in_order;
use proptest::prelude::*;

use crate::entity_strategies::{
    agent_kind, one_agent_doer, ordinary_timestamp, task_with_doer,
    workflow_doer,
};
use crate::run_creation_support::{create_test_run, workflow_id_from};
use crate::workflow_strategies::{
    acyclic_workflow, arbitrary_workflow, workflow_identifier,
    workflow_with_cycle,
};

fn planned_run() -> impl Strategy<Value = Run> {
    let one_agent_run =
        (task_with_doer(one_agent_doer()), ordinary_timestamp())
            .prop_filter_map("plans", |(task, started_at)| {
                create_test_run(&task, None, started_at).ok()
            });
    let workflow_task = task_with_doer(workflow_doer(workflow_identifier()));
    let workflow_run =
        (acyclic_workflow(), workflow_task, ordinary_timestamp())
            .prop_filter_map("plans", |(workflow, task, started_at)| {
                create_test_run(&task, Some(&workflow), started_at).ok()
            });
    prop_oneof![one_agent_run, workflow_run]
}

proptest! {
    #[test]
    fn test_plan_steps_property_one_agent_runs_one_step(
        task in task_with_doer(one_agent_doer()),
        started_at in ordinary_timestamp(),
    ) {
        let run = create_test_run(&task, None, started_at);

        let step_count = run.as_ref().map(|run| run.steps.len());
        prop_assert_eq!(step_count, Ok(1));
    }

    #[test]
    fn test_plan_steps_property_one_agent_takes_no_workflow(
        task in task_with_doer(one_agent_doer()),
        workflow in arbitrary_workflow(),
        started_at in ordinary_timestamp(),
    ) {
        let run = create_test_run(&task, Some(&workflow), started_at);

        prop_assert_eq!(run, Err(RunProblem::UnexpectedWorkflow));
    }

    #[test]
    fn test_plan_steps_property_a_workflow_task_needs_its_workflow(
        workflow_number in any::<u128>(),
        started_at in ordinary_timestamp(),
        task in task_with_doer(one_agent_doer()),
    ) {
        let workflow_id = workflow_id_from(workflow_number);
        let workflow_task = Task {
            doer: TaskDoer::Workflow { workflow_id },
            ..task
        };

        let run = create_test_run(&workflow_task, None, started_at);

        prop_assert_eq!(run, Err(RunProblem::MissingWorkflow { workflow_id }));
    }

    #[test]
    fn test_plan_single_agent_step_property_names_the_step_after_the_agent(
        agent in agent_kind(),
        task in task_with_doer(one_agent_doer()),
    ) {
        let agent_task = Task { doer: TaskDoer::OneAgent { agent }, ..task };
        let wire_name = serde_json::to_value(agent).ok();

        let run = create_test_run(&agent_task, None, agent_task.created_at);

        let step_names: Option<Vec<String>> = run
            .ok()
            .map(|run| run.steps.into_iter().map(|step| step.name).collect());
        let expected_name = wire_name
            .as_ref()
            .and_then(serde_json::Value::as_str)
            .map(|name| name.replace('_', "-"));
        prop_assert!(expected_name.is_some());
        prop_assert_eq!(step_names, expected_name.map(|name| vec![name]));
    }

    #[test]
    fn test_plan_single_agent_step_property_has_no_workflow_agent(
        task in task_with_doer(one_agent_doer()),
        started_at in ordinary_timestamp(),
    ) {
        let run = create_test_run(&task, None, started_at);

        let agent_ids = run.map(|run| {
            run.steps.into_iter().map(|step| step.agent_id).collect()
        });
        prop_assert_eq!(agent_ids, Ok(vec![None]));
    }

    #[test]
    fn test_plan_single_agent_step_property_ignores_other_task_fields(
        first_task in task_with_doer(one_agent_doer()),
        second_task in task_with_doer(one_agent_doer()),
        started_at in ordinary_timestamp(),
    ) {
        let same_agent_task = Task {
            doer: first_task.doer.clone(),
            ..second_task
        };

        let first_run = create_test_run(&first_task, None, started_at);
        let second_run = create_test_run(&same_agent_task, None, started_at);

        let first_steps = first_run.map(|run| run.steps);
        prop_assert_eq!(second_run.map(|run| run.steps), first_steps);
    }

    #[test]
    fn test_plan_workflow_steps_property_refuses_another_workflow(
        workflow in acyclic_workflow(),
        expected_number in any::<u128>(),
        task in task_with_doer(one_agent_doer()),
    ) {
        let expected = workflow_id_from(expected_number);
        prop_assume!(expected != workflow.id);
        let workflow_task = Task {
            doer: TaskDoer::Workflow { workflow_id: expected },
            ..task
        };

        let started_at = task.created_at;
        let run = create_test_run(&workflow_task, Some(&workflow), started_at);

        let given = workflow.id;
        let problem = RunProblem::WrongWorkflow { expected, given };
        prop_assert_eq!(run, Err(problem));
    }

    #[test]
    fn test_plan_workflow_steps_property_checks_the_id_before_the_graph(
        workflow in workflow_with_cycle(),
        expected_number in any::<u128>(),
        task in task_with_doer(one_agent_doer()),
    ) {
        let expected = workflow_id_from(expected_number);
        prop_assume!(expected != workflow.id);
        let workflow_task = Task {
            doer: TaskDoer::Workflow { workflow_id: expected },
            ..task
        };

        let started_at = task.created_at;
        let run = create_test_run(&workflow_task, Some(&workflow), started_at);

        let given = workflow.id;
        let problem = RunProblem::WrongWorkflow { expected, given };
        prop_assert_eq!(run, Err(problem));
    }

    #[test]
    fn test_plan_workflow_steps_property_one_step_per_agent_in_order(
        workflow in acyclic_workflow(),
        task in task_with_doer(workflow_doer(workflow_identifier())),
    ) {
        let run = create_test_run(&task, Some(&workflow), task.created_at);

        let mut expected_steps = Vec::new();
        for agent in agents_in_order(&workflow) {
            expected_steps.push((agent.name.clone(), Some(agent.id)));
        }
        let planned_steps: Result<Vec<_>, RunProblem> = run.map(|run| {
            run.steps
                .into_iter()
                .map(|step| (step.name, step.agent_id))
                .collect()
        });
        prop_assert_eq!(planned_steps, Ok(expected_steps));
    }

    #[test]
    fn test_waiting_step_property_records_nothing_yet(run in planned_run()) {
        for step in &run.steps {
            prop_assert_eq!(step.status, StepStatus::Waiting);
            prop_assert_eq!(&step.runner, &None);
            prop_assert_eq!(step.started_at, None);
            prop_assert_eq!(step.finished_at, None);
            prop_assert_eq!(&step.result, &None);
            prop_assert_eq!(&step.outcome, &None);
            prop_assert_eq!(&step.loop_source, &None);
            prop_assert!(step.earlier_rounds.is_empty());
        }
    }

    #[test]
    fn test_waiting_step_property_names_and_agents_are_unique(
        run in planned_run(),
    ) {
        let mut names = BTreeSet::new();
        let mut agent_ids = BTreeSet::new();
        for step in &run.steps {
            prop_assert!(names.insert(step.name.clone()));
            if let Some(agent_id) = step.agent_id {
                prop_assert!(agent_ids.insert(agent_id));
            }
        }
    }

    #[test]
    fn test_waiting_step_property_steps_make_a_fresh_queued_run(
        run in planned_run(),
    ) {
        prop_assert_eq!(derive_run_status(&run.steps), RunStatus::Queued);
        prop_assert_eq!(run.status, RunStatus::Queued);
        prop_assert_eq!(run.finished_at, None);
        prop_assert_eq!(run.link, RunnerLink::Unreachable);
        prop_assert_eq!(run.link_lost_at, None);
        prop_assert!(run.loop_rounds.is_empty() && run.notes.is_empty());
        prop_assert_eq!(&run.failure, &None);
        prop_assert_eq!(&run.agent_session, &None);
    }
}
