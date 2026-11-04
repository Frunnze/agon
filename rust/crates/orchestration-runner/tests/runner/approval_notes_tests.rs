use chrono::DateTime;
use orchestration_api::work::RunEvent;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::run::StepStatus;
use orchestration_runner::approval_notes::{
    describe_automatic_push, describe_push, describe_step_start, note_in_log,
};
use proptest::prelude::*;

const BRANCH_PATTERN: &str = "task/[a-z-]{1,20}";
const MAXIMUM_COMMITS: usize = 500;

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn count_log_lines(events: &[RunEvent]) -> usize {
    let mut log_line_count = 0;
    for event in events {
        if matches!(event, RunEvent::LogAppended { .. }) {
            log_line_count += 1;
        }
    }
    log_line_count
}

proptest! {
    #[test]
    fn test_describe_push_property_names_the_count_and_the_branch(
        commit_count in 0..MAXIMUM_COMMITS,
        branch in BRANCH_PATTERN,
    ) {
        let text = describe_push(commit_count, &branch);

        let noun = if commit_count == 1 { "commit" } else { "commits" };
        let expected = format!("Pushed {commit_count} {noun} to {branch}");
        prop_assert_eq!(text, expected);
    }

    #[test]
    fn test_describe_automatic_push_property_marks_the_push_as_auto(
        commit_count in 0..MAXIMUM_COMMITS,
        branch in BRANCH_PATTERN,
    ) {
        let text = describe_automatic_push(commit_count, &branch);

        let push = describe_push(commit_count, &branch);
        let expected = format!("{push} (auto)");
        prop_assert_eq!(text, expected);
    }

    #[test]
    fn test_describe_step_start_property_notes_auto_tools_only_on_auto(
        step_name in "[a-z-]{1,20}",
        approval_policy in any_policy(),
    ) {
        let events = describe_step_start(
            &step_name,
            approval_policy,
            DateTime::UNIX_EPOCH,
        );

        let running = RunEvent::StepStatusChanged {
            step_name: step_name.clone(),
            status: StepStatus::Running,
        };
        let is_auto = approval_policy == ApprovalPolicy::NeverAsk;
        prop_assert_eq!(events.first(), Some(&running));
        prop_assert_eq!(count_log_lines(&events), usize::from(is_auto));
    }

    #[test]
    fn test_note_in_log_property_keeps_the_step_and_text(
        step_name in "[a-z-]{1,20}",
        text in "[A-Za-z ,()]{1,60}",
    ) {
        let event = note_in_log(&step_name, &text, DateTime::UNIX_EPOCH);

        let RunEvent::LogAppended { line } = event else {
            return Err(TestCaseError::fail("not a log line"));
        };
        prop_assert_eq!(line.step_name, step_name);
        prop_assert_eq!(line.text, text);
        prop_assert!(!line.is_error);
    }
}
