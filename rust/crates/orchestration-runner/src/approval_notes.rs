use chrono::{DateTime, Utc};
use orchestration_api::work::RunEvent;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::run::{LogLine, StepStatus};

const AUTOMATIC_TOOLS_NOTE: &str =
    "Tool permissions: Auto, the agent uses its tools without asking";
const AUTOMATIC_SUFFIX: &str = " (auto)";
const ONE_COMMIT: &str = "1 commit";

#[must_use]
pub fn describe_push(commit_count: usize, branch: &str) -> String {
    let commits = if commit_count == 1 {
        ONE_COMMIT.to_owned()
    } else {
        format!("{commit_count} commits")
    };
    format!("Pushed {commits} to {branch}")
}

#[must_use]
pub fn describe_automatic_push(commit_count: usize, branch: &str) -> String {
    let push = describe_push(commit_count, branch);
    format!("{push}{AUTOMATIC_SUFFIX}")
}

#[must_use]
pub fn describe_step_start(
    step_name: &str,
    approval_policy: ApprovalPolicy,
    at: DateTime<Utc>,
) -> Vec<RunEvent> {
    let mut events = vec![RunEvent::StepStatusChanged {
        step_name: step_name.to_owned(),
        status: StepStatus::Running,
    }];
    if approval_policy == ApprovalPolicy::NeverAsk {
        events.push(note_in_log(step_name, AUTOMATIC_TOOLS_NOTE, at));
    }
    events
}

#[must_use]
pub fn note_in_log(
    step_name: &str,
    text: &str,
    at: DateTime<Utc>,
) -> RunEvent {
    RunEvent::LogAppended {
        line: LogLine {
            at,
            step_name: step_name.to_owned(),
            text: text.to_owned(),
            is_error: false,
        },
    }
}
