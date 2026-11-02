use std::sync::Arc;

use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::WorkflowId;
use orchestration_core::run::StepStatus;
use orchestration_core::task::TaskDoer;
use orchestration_runner::run_executor::RunOutcome;
use proptest::prelude::*;
use tokio::runtime::Runtime;
use uuid::Uuid;

use crate::assignments::{assignment_for, task_for};
use crate::event_queries::{failures, step_results, step_statuses};
use crate::executor_support::{RUN_NUMBER, execute_with_git_pusher};
use crate::fake_agent::{
    AgentFolders, local_configuration, prepare_agent_folders, read_prompt,
};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, to_case_error};
use crate::workflows::{
    WORKFLOW_NUMBER, WorkflowShape, agent_name, any_workflow_shape,
    build_workflow,
};

struct StepRun {
    folders: AgentFolders,
    step_name: String,
    upstream_names: Vec<String>,
    other_names: Vec<String>,
    is_failing: bool,
    outcome: RunOutcome,
    events: Vec<RunEvent>,
}

fn upstream_result(step_name: &str) -> String {
    format!("finished {step_name}")
}

fn unrelated_result(step_name: &str) -> String {
    format!("unrelated work of {step_name}")
}

fn name_upstream_steps(shape: &WorkflowShape, chosen: usize) -> Vec<String> {
    let mut upstream = Vec::new();
    for (from, to) in &shape.connections {
        if *to == chosen {
            upstream.push(agent_name(*from));
        }
    }
    upstream
}

fn execute_one_step(
    shape: &WorkflowShape,
    chosen: usize,
) -> TestResult<StepRun> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let doer = TaskDoer::Workflow {
        workflow_id: WorkflowId(Uuid::from_u128(WORKFLOW_NUMBER)),
    };
    let task = task_for(RUN_NUMBER, "Generated workflow", doer);
    let workflow = build_workflow(shape);
    let mut assignment =
        assignment_for(task, Some(workflow), Vec::new(), RUN_NUMBER)?;
    let step_name = agent_name(chosen);
    let upstream = name_upstream_steps(shape, chosen);
    let mut upstream_names = Vec::new();
    let mut other_names = Vec::new();
    for step in &mut assignment.run.steps {
        if step.name == step_name {
            continue;
        }
        if upstream.contains(&step.name) {
            step.status = StepStatus::Done;
            step.result = Some(upstream_result(&step.name));
            upstream_names.push(step.name.clone());
        } else {
            step.result = Some(unrelated_result(&step.name));
            other_names.push(step.name.clone());
        }
    }
    assignment.step_name.clone_from(&step_name);
    let run_id = assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));
    let runtime = Runtime::new()?;

    let outcome = runtime.block_on(execute_with_git_pusher(
        &server,
        &configuration,
        assignment,
    ))?;
    Ok(StepRun {
        folders,
        is_failing: shape.failing_agents.get(chosen) == Some(&true),
        step_name,
        upstream_names,
        other_names,
        outcome,
        events: server.events_of(run_id),
    })
}

fn any_shape_and_step() -> impl Strategy<Value = (WorkflowShape, usize)> {
    any_workflow_shape().prop_flat_map(|shape| {
        let agent_count = shape.agent_count;
        (Just(shape), 0..agent_count)
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(10))]

    #[test]
    fn test_execute_property_runs_only_the_assigned_step(
        (shape, chosen) in any_shape_and_step(),
    ) {
        let run = execute_one_step(&shape, chosen).map_err(to_case_error)?;

        let final_status = if run.is_failing {
            StepStatus::Failed
        } else {
            StepStatus::Done
        };
        let expected_statuses = vec![
            (run.step_name.clone(), StepStatus::Running),
            (run.step_name.clone(), final_status),
        ];
        prop_assert_eq!(step_statuses(&run.events), expected_statuses);
        prop_assert!(!run.events.contains(&RunEvent::Finished));
        let expected_outcome = if run.is_failing {
            RunOutcome::Failed
        } else {
            RunOutcome::Finished
        };
        prop_assert_eq!(run.outcome, expected_outcome);
        let failure_count = failures(&run.events).len();
        prop_assert_eq!(failure_count, usize::from(run.is_failing));
    }

    #[test]
    fn test_execute_property_prompt_holds_exactly_the_upstream_results(
        (shape, chosen) in any_shape_and_step(),
    ) {
        let run = execute_one_step(&shape, chosen).map_err(to_case_error)?;

        let prompt =
            read_prompt(&run.folders, &run.step_name).map_err(to_case_error)?;
        for upstream_name in &run.upstream_names {
            prop_assert!(prompt.contains(&upstream_result(upstream_name)));
        }
        for other_name in &run.other_names {
            prop_assert!(!prompt.contains(&unrelated_result(other_name)));
        }
    }

    #[test]
    fn test_execute_property_posts_the_result_right_before_done(
        (shape, chosen) in any_shape_and_step(),
    ) {
        let run = execute_one_step(&shape, chosen).map_err(to_case_error)?;

        if run.is_failing {
            prop_assert!(step_results(&run.events).is_empty());
            return Ok(());
        }
        let own_result = upstream_result(&run.step_name);
        let expected_ending = [
            RunEvent::StepResultRecorded {
                step_name: run.step_name.clone(),
                result: own_result,
            },
            RunEvent::StepStatusChanged {
                step_name: run.step_name.clone(),
                status: StepStatus::Done,
            },
        ];
        prop_assert!(run.events.ends_with(&expected_ending));
        prop_assert_eq!(step_results(&run.events).len(), 1);
    }
}
