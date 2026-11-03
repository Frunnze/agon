use std::sync::Arc;

use orchestration_core::agent_place::AgentPlace;
use orchestration_core::run::StepStatus;
use orchestration_core::task::Task;
use orchestration_runner::run_executor::RunOutcome;
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, claude_task};
use crate::event_queries::{failures, step_statuses};
use crate::executor_support::{
    RUN_NUMBER, STEP_NAME, execute_with_git_pusher,
};
use crate::fake_agent::{
    has_agent_records, local_configuration, prepare_agent_folders,
};
use crate::fake_server::FakeServer;
use crate::support::to_case_error;

const PLACE_REASON: &str =
    "this runner does not offer where the task's agents run";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_execute_property_a_place_the_runner_lacks_never_starts_the_agent(
        title in "[A-Za-z ]{1,20}",
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let configuration =
            local_configuration(&folders, 1).map_err(to_case_error)?;
        let task = Task {
            agent_place: Some(AgentPlace::Container),
            ..claude_task(RUN_NUMBER, &title)
        };
        let assignment = assignment_for(task, None, Vec::new(), RUN_NUMBER)
            .map_err(to_case_error)?;
        let run_id = assignment.run.id;
        let server = Arc::new(FakeServer::with_queue(Vec::new()));
        let runtime = Runtime::new().map_err(to_case_error)?;

        let outcome = runtime
            .block_on(execute_with_git_pusher(
                &server,
                &configuration,
                assignment,
            ))
            .map_err(to_case_error)?;

        let events = server.events_of(run_id);
        let reported_failures = failures(&events);
        prop_assert_eq!(outcome, RunOutcome::Failed);
        prop_assert_eq!(
            step_statuses(&events),
            vec![(STEP_NAME.to_string(), StepStatus::Failed)]
        );
        prop_assert_eq!(reported_failures.len(), 1);
        prop_assert_eq!(&reported_failures[0].reason, PLACE_REASON);
        let has_records =
            has_agent_records(&folders).map_err(to_case_error)?;
        prop_assert!(!has_records);
    }
}
