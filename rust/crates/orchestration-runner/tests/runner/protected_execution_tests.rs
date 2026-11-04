use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::AgentKind;
use orchestration_runner::run_executor::RunOutcome;
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, task_for};
use crate::event_queries::failures;
use crate::executor_support::{RUN_NUMBER, execute_with_git_pusher};
use crate::fake_agent::{
    has_agent_records, local_configuration, prepare_agent_folders,
};
use crate::fake_server::FakeServer;
use crate::support::to_case_error;

const REFUSAL_WORDS: [&str; 2] = ["can't read", "Docker"];

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_execute_property_other_agents_on_this_computer_are_refused(
        agent in prop_oneof![
            Just(AgentKind::Codex),
            Just(AgentKind::GeminiCli),
        ],
        title in "[A-Za-z ]{1,20}",
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let configuration =
            local_configuration(&folders, 1).map_err(to_case_error)?;
        let task = task_for(RUN_NUMBER, &title, TaskDoer::OneAgent { agent });
        let assignment = assignment_for(task, None, Vec::new(), RUN_NUMBER)
            .map_err(to_case_error)?;
        let assignment = RunAssignment {
            protected_files: ProtectedFiles::default(),
            ..assignment
        };
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

        let reported_failures = failures(&server.events_of(run_id));
        prop_assert_eq!(outcome, RunOutcome::Failed);
        prop_assert_eq!(reported_failures.len(), 1);
        for word in REFUSAL_WORDS {
            let reason = &reported_failures[0].reason;
            prop_assert!(reason.contains(word), "{reason}");
        }
        let has_records =
            has_agent_records(&folders).map_err(to_case_error)?;
        prop_assert!(!has_records);
    }
}
