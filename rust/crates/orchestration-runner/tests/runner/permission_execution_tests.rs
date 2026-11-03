use std::fs;
use std::sync::Arc;

use orchestration_api::work::{CreateApprovalRequest, RunAssignment};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalPolicy,
};
use orchestration_core::run::StepStatus;
use orchestration_core::task::Task;
use orchestration_runner::run_executor::RunOutcome;
use proptest::prelude::*;
use serde_json::{Value, json};
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, claude_task};
use crate::event_queries::step_statuses;
use crate::executor_support::{
    RUN_NUMBER, STEP_NAME, execute_with_git_pusher, server_answering,
    step_status_pairs,
};
use crate::fake_agent::{
    AgentFolders, local_configuration, prepare_agent_folders, read_calls,
};
use crate::fake_server::{ApprovalAnswer, CancellationRule, FakeServer};
use crate::support::{TestResult, to_case_error};

const ASKING_TITLE: &str = "check-tests\nplease-ask";
const AGENT_NAME: &str = "check-tests";
const ASKED_COMMAND: &str = "npm test";
const DENIED_MESSAGE: &str = "The person denied this command.";

struct PermissionScenario {
    folders: AgentFolders,
    assignment: RunAssignment,
}

fn prepare_scenario(
    approval_policy: ApprovalPolicy,
) -> TestResult<PermissionScenario> {
    let folders = prepare_agent_folders()?;
    let task = Task {
        approval_policy,
        ..claude_task(RUN_NUMBER, ASKING_TITLE)
    };
    let assignment = assignment_for(task, None, Vec::new(), RUN_NUMBER)?;
    Ok(PermissionScenario {
        folders,
        assignment,
    })
}

async fn execute_scenario(
    scenario: &PermissionScenario,
    server: &Arc<FakeServer>,
) -> TestResult<RunOutcome> {
    let configuration = local_configuration(&scenario.folders, 1)?;
    let assignment = scenario.assignment.clone();
    execute_with_git_pusher(server, &configuration, assignment).await
}

fn read_agent_answer(folders: &AgentFolders) -> TestResult<Option<Value>> {
    let answer_file = format!("answer-{AGENT_NAME}.txt");
    let answer_path = folders.records.join(answer_file);
    if !answer_path.exists() {
        return Ok(None);
    }
    let answer_text = fs::read_to_string(answer_path)?;
    Ok(Some(serde_json::from_str(&answer_text)?))
}

fn expected_command_request(
    scenario: &PermissionScenario,
) -> Vec<CreateApprovalRequest> {
    vec![CreateApprovalRequest {
        run_id: Some(scenario.assignment.run.id),
        action: ApprovalAction::RunCommand {
            tool: "Bash".to_string(),
            command: ASKED_COMMAND.to_string(),
        },
    }]
}

fn expected_answer(decision: ApprovalDecision) -> Value {
    let behavior = match decision {
        ApprovalDecision::Approved => json!({
            "behavior": "allow",
            "updatedInput": {"command": ASKED_COMMAND},
        }),
        ApprovalDecision::Denied => json!({
            "behavior": "deny",
            "message": DENIED_MESSAGE,
        }),
    };
    json!({
        "type": "control_response",
        "response": {
            "subtype": "success",
            "request_id": format!("ask-{AGENT_NAME}"),
            "response": behavior,
        },
    })
}

#[tokio::test(flavor = "multi_thread")]
async fn an_approved_command_lets_the_agent_carry_on() -> TestResult<()> {
    let scenario = prepare_scenario(ApprovalPolicy::AskBeforeRiskyActions)?;
    let server = server_answering(ApprovalDecision::Approved);

    let outcome = execute_scenario(&scenario, &server).await?;

    let events = server.events_of(scenario.assignment.run.id);
    let expected_statuses = step_status_pairs(&[
        StepStatus::Running,
        StepStatus::WaitingForApproval,
        StepStatus::Running,
        StepStatus::Done,
    ]);
    let expected = expected_answer(ApprovalDecision::Approved);
    assert_eq!(outcome, RunOutcome::Finished);
    let expected_requests = expected_command_request(&scenario);
    assert_eq!(server.approval_requests(), expected_requests);
    assert_eq!(read_agent_answer(&scenario.folders)?, Some(expected));
    assert_eq!(step_statuses(&events), expected_statuses);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn a_denied_command_tells_the_agent_why() -> TestResult<()> {
    let scenario = prepare_scenario(ApprovalPolicy::AskBeforeRiskyActions)?;
    let server = server_answering(ApprovalDecision::Denied);

    let outcome = execute_scenario(&scenario, &server).await?;

    let expected = expected_answer(ApprovalDecision::Denied);
    assert_eq!(outcome, RunOutcome::Finished);
    let expected_requests = expected_command_request(&scenario);
    assert_eq!(server.approval_requests(), expected_requests);
    assert_eq!(read_agent_answer(&scenario.folders)?, Some(expected));
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn cancelling_while_a_command_waits_stops_the_agent() -> TestResult<()> {
    let scenario = prepare_scenario(ApprovalPolicy::AskBeforeRiskyActions)?;
    let server = Arc::new(
        FakeServer::with_queue(Vec::new())
            .answering_approvals(ApprovalAnswer::NeverDecide)
            .cancelling(CancellationRule::WhenApprovalRequested),
    );

    let outcome = execute_scenario(&scenario, &server).await?;

    let events = server.events_of(scenario.assignment.run.id);
    let waiting = (STEP_NAME.to_string(), StepStatus::WaitingForApproval);
    assert_eq!(outcome, RunOutcome::Cancelled);
    assert_eq!(read_agent_answer(&scenario.folders)?, None);
    assert_eq!(step_statuses(&events).last(), Some(&waiting));
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn a_silent_agent_never_raises_a_command_approval() -> TestResult<()> {
    let scenario = prepare_scenario(ApprovalPolicy::NeverAsk)?;
    let server = server_answering(ApprovalDecision::Denied);

    let outcome = execute_scenario(&scenario, &server).await?;

    assert_eq!(outcome, RunOutcome::Finished);
    let no_requests: Vec<CreateApprovalRequest> = Vec::new();
    assert_eq!(server.approval_requests(), no_requests);
    assert_eq!(read_agent_answer(&scenario.folders)?, None);
    assert_eq!(read_calls(&scenario.folders)?, vec!["check-tests none"]);
    Ok(())
}

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn any_decision() -> impl Strategy<Value = ApprovalDecision> {
    prop_oneof![
        Just(ApprovalDecision::Approved),
        Just(ApprovalDecision::Denied),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(6))]

    #[test]
    fn test_execute_property_commands_are_asked_about_only_when_asking(
        approval_policy in any_policy(),
        decision in any_decision(),
    ) {
        let scenario =
            prepare_scenario(approval_policy).map_err(to_case_error)?;
        let server = server_answering(decision);
        let runtime = Runtime::new().map_err(to_case_error)?;

        let outcome = runtime
            .block_on(execute_scenario(&scenario, &server))
            .map_err(to_case_error)?;

        let asks = approval_policy == ApprovalPolicy::AskBeforeRiskyActions;
        let answer =
            read_agent_answer(&scenario.folders).map_err(to_case_error)?;
        let expected_answer = asks.then(|| expected_answer(decision));
        prop_assert_eq!(outcome, RunOutcome::Finished);
        prop_assert_eq!(server.approval_requests().len(), usize::from(asks));
        prop_assert_eq!(answer, expected_answer);
    }
}
