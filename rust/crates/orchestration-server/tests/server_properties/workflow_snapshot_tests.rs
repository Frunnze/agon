use orchestration_core::run::RunStatus;
use orchestration_core::workflow::{AgentConnection, StepKind, Workflow};
use proptest::prelude::*;

use crate::branching_fixtures::{
    branching_workflow, claim_and_finish, read_run, start_branching_run,
};
use crate::fixtures::{heartbeat_with, send_heartbeat};
use crate::test_client::{TestServer, block_on};
use crate::workflow_fixtures::{change_and_sign_workflow, workflow_agent};

const MAXIMUM_ADDED_STEPS: usize = 3;

fn started_version() -> Workflow {
    let steps = [("plan", StepKind::Agent), ("build", StepKind::Agent)];
    branching_workflow(&steps, &[(0, 1, None, None)])
}

fn version_without_build(started: &Workflow, added_steps: usize) -> Workflow {
    let plan = started.agents[0].clone();
    let mut agents = vec![plan.clone()];
    let mut connections = Vec::new();
    for number in 0..added_steps {
        let name = format!("deploy-{number}");
        let added = workflow_agent(&name, plan.runs_on.clone());
        connections.push(AgentConnection::plain(plan.id, added.id));
        agents.push(added);
    }
    Workflow {
        agents,
        connections,
        ..started.clone()
    }
}

fn list_step_names(workflow: &Workflow) -> Vec<String> {
    workflow
        .agents
        .iter()
        .map(|agent| agent.name.clone())
        .collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_find_run_workflow_property_a_running_run_keeps_its_version(
        added_steps in 0..=MAXIMUM_ADDED_STEPS,
    ) {
        let test = TestServer::start();
        let started_workflow = started_version();
        let (build_assignment, run) = block_on(async {
            let started =
                start_branching_run(&test, started_workflow.clone(), 1, 1)
                    .await;
            let runner = &started.runners[0];
            let changed =
                version_without_build(&started_workflow, added_steps);
            change_and_sign_workflow(&test, &started.account, changed).await;

            claim_and_finish(&test, runner, "plan", None).await;
            send_heartbeat(&test, runner, &heartbeat_with(&[], 1, 0)).await;
            let build = claim_and_finish(&test, runner, "build", None).await;
            let run = read_run(&test, &started.account, &started.run).await;
            (build, run)
        });

        let assigned_workflow = build_assignment.workflow;
        prop_assert_eq!(
            assigned_workflow.as_ref().map(list_step_names),
            Some(list_step_names(&started_workflow)),
        );
        prop_assert_eq!(run.status, RunStatus::Done);
        let run_steps: Vec<String> =
            run.steps.iter().map(|step| step.name.clone()).collect();
        prop_assert_eq!(run_steps, list_step_names(&started_workflow));
    }
}
