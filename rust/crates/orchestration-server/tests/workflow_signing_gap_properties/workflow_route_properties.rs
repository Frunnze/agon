use axum::http::StatusCode;
use orchestration_api::catalog::{SaveWorkflowRequest, WorkflowListing};
use orchestration_api::routes::WORKFLOWS;
use orchestration_api::updates::ApiErrorBody;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::WorkflowId;
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::{AgentConnection, Workflow};
use proptest::collection::btree_set;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{Account, create_account};
use crate::test_client::{TestResponse, TestServer, block_on};
use crate::workflow_fixtures::{create_signed_workflow, workflow_agent};

const ROUTE_CASES: u32 = 8;
const OUTCOME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const FORK_OUTCOME_COUNT: usize = 2;
const START_STEP: usize = 0;
const BUILD_STEP: usize = 1;
const REPEATED_PAIR_TEXT: &str = "two connections from start to build";
const RULE_BREAKING_NAMES: [&str; 6] = [
    "Plan",
    "write code",
    "run_tests",
    "café",
    "",
    "build, at most 3 rounds",
];

fn fork_outcomes() -> impl Strategy<Value = Vec<String>> {
    btree_set(OUTCOME_PATTERN, FORK_OUTCOME_COUNT)
        .prop_map(|outcomes| outcomes.into_iter().collect())
}

fn fork_workflow(outcomes: &[String]) -> Workflow {
    let mut agents = Vec::new();
    for name in ["start", "build", "check"] {
        agents.push(workflow_agent(name, RunnerTarget::AnyFreeRunner));
    }
    let mut connections = Vec::new();
    for (target, outcome) in agents.iter().skip(1).zip(outcomes) {
        connections.push(AgentConnection {
            condition: Some(outcome.clone()),
            ..AgentConnection::plain(agents[START_STEP].id, target.id)
        });
    }
    Workflow {
        id: WorkflowId(Uuid::new_v4()),
        name: "release".to_owned(),
        availability: WorkspaceScope::AllWorkspaces,
        agents,
        connections,
        signature: None,
    }
}

fn with_plain_copy(workflow: &Workflow) -> Workflow {
    let plain_copy = AgentConnection::plain(
        workflow.agents[START_STEP].id,
        workflow.agents[BUILD_STEP].id,
    );
    let mut connections = vec![plain_copy];
    connections.extend(workflow.connections.iter().cloned());
    Workflow {
        connections,
        signature: None,
        ..workflow.clone()
    }
}

async fn post_workflow(
    test: &TestServer,
    account: &Account,
    workflow: Workflow,
) -> TestResponse {
    let request = SaveWorkflowRequest { workflow };
    test.post(&account.owner, WORKFLOWS, &request).await
}

async fn list_workflows(
    test: &TestServer,
    account: &Account,
) -> Vec<WorkflowListing> {
    let response = test.get(&account.owner, WORKFLOWS).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ROUTE_CASES))]

    #[test]
    fn test_create_workflow_property_refuses_a_repeated_step_pair(
        outcomes in fork_outcomes(),
    ) {
        let test = TestServer::start();
        let (response, listings) = block_on(async {
            let account = create_account(&test).await;
            let colliding = with_plain_copy(&fork_workflow(&outcomes));
            let response = post_workflow(&test, &account, colliding).await;
            (response, list_workflows(&test, &account).await)
        });

        prop_assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
        let refusal: ApiErrorBody = response.json();
        prop_assert!(refusal.message.contains(REPEATED_PAIR_TEXT));
        prop_assert!(listings.is_empty());
    }

    #[test]
    fn test_create_workflow_property_refuses_a_rule_breaking_step_name(
        outcomes in fork_outcomes(),
        name_position in 0..RULE_BREAKING_NAMES.len(),
    ) {
        let name = RULE_BREAKING_NAMES[name_position];
        let test = TestServer::start();
        let (response, listings) = block_on(async {
            let account = create_account(&test).await;
            let mut badly_named = fork_workflow(&outcomes);
            name.clone_into(&mut badly_named.agents[BUILD_STEP].name);
            let response = post_workflow(&test, &account, badly_named).await;
            (response, list_workflows(&test, &account).await)
        });

        prop_assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
        let refusal: ApiErrorBody = response.json();
        let quoted_name = format!("{name:?}");
        prop_assert!(refusal.message.contains(&quoted_name));
        prop_assert!(listings.is_empty());
    }

    #[test]
    fn test_update_workflow_property_refuses_a_document_collision(
        outcomes in fork_outcomes(),
    ) {
        let test = TestServer::start();
        let (signed, response, listings) = block_on(async {
            let account = create_account(&test).await;
            let honest = fork_workflow(&outcomes);
            let signed =
                create_signed_workflow(&test, &account, honest).await;
            let colliding = with_plain_copy(&signed);
            let path = format!("{WORKFLOWS}/{}", signed.id.0);
            let request = SaveWorkflowRequest { workflow: colliding };
            let response = test.put(&account.owner, &path, &request).await;
            (signed, response, list_workflows(&test, &account).await)
        });

        prop_assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
        let [listing] = listings.as_slice() else {
            return Err(TestCaseError::fail("one workflow is listed"));
        };
        prop_assert_eq!(&listing.workflow.connections, &signed.connections);
        prop_assert!(listing.workflow.signature.is_some());
    }
}
