use orchestration_api::work::RunAssignment;
use orchestration_core::approval::{ApprovalDecision, ApprovalPolicy};
use orchestration_core::approval_levels::{
    ApprovalLevels, resolve_approval_policy,
};
use orchestration_core::task::Task;
use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_runner::step_plan::plan_assigned_step;
use proptest::option;
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::{assignment_for, claude_task};
use crate::event_queries::{branches, log_texts};
use crate::executor_support::{
    RUN_NUMBER, execute_with_git_pusher, server_answering,
};
use crate::fake_agent::{local_configuration, prepare_agent_folders};
use crate::git_support::{create_bare_origin, repository_at};
use crate::support::{TestResult, to_case_error};

const COMMITTING_TITLE: &str = "add-feature\nplease-commit";
const AUTO_TOOLS_LINE: &str =
    "Tool permissions: Auto, the agent uses its tools without asking";
const LEVEL_CASES: u32 = 8;

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn assignment_with_levels(
    levels: ApprovalLevels,
    repositories: Vec<Repository>,
) -> TestResult<RunAssignment> {
    let task = Task {
        approval_policy: levels.step,
        ..claude_task(RUN_NUMBER, COMMITTING_TITLE)
    };
    let mut assignment = assignment_for(task, None, repositories, RUN_NUMBER)?;
    assignment.workspace_approval_policy = levels.workspace;
    if let Some(project) = assignment.project.as_mut() {
        project.approval_policy = levels.project;
    }
    Ok(assignment)
}

struct LevelRun {
    approval_request_count: usize,
    log_lines: Vec<String>,
    branch: String,
}

async fn run_with_levels(levels: ApprovalLevels) -> TestResult<LevelRun> {
    let folders = prepare_agent_folders()?;
    let origin = create_bare_origin(folders.temporary.path(), "app", &[])?;
    let repository = repository_at(&origin, AgentAccess::PushAfterApproval);
    let assignment = assignment_with_levels(levels, vec![repository])?;
    let configuration = local_configuration(&folders, 1)?;
    let run_id = assignment.run.id;
    let server = server_answering(ApprovalDecision::Approved);

    execute_with_git_pusher(&server, &configuration, assignment).await?;

    let events = server.events_of(run_id);
    let branch = branches(&events).pop().ok_or("no worktree branch")?;
    Ok(LevelRun {
        approval_request_count: server.approval_requests().len(),
        log_lines: log_texts(&events),
        branch,
    })
}

#[test]
fn test_plan_assigned_step_starts_untouched_levels_on_auto() -> TestResult<()>
{
    let levels = ApprovalLevels {
        step: None,
        project: None,
        workspace: ApprovalPolicy::default(),
    };
    let assignment = assignment_with_levels(levels, Vec::new())?;

    let step = plan_assigned_step(&assignment)?;

    assert_eq!(step.approval_policy, ApprovalPolicy::NeverAsk);
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LEVEL_CASES))]

    #[test]
    fn test_plan_assigned_step_property_follows_the_approval_levels(
        step in option::of(any_policy()),
        project in option::of(any_policy()),
        workspace in any_policy(),
    ) {
        let levels = ApprovalLevels { step, project, workspace };
        let assignment = assignment_with_levels(levels, Vec::new())
            .map_err(to_case_error)?;

        let planned = plan_assigned_step(&assignment).map_err(to_case_error)?;

        prop_assert_eq!(
            planned.approval_policy,
            resolve_approval_policy(levels)
        );
    }

    #[test]
    fn test_execute_property_asks_or_pushes_by_the_resolved_level(
        project in option::of(any_policy()),
        workspace in any_policy(),
    ) {
        let levels = ApprovalLevels { step: None, project, workspace };
        let runtime = Runtime::new().map_err(to_case_error)?;

        let run = runtime
            .block_on(run_with_levels(levels))
            .map_err(to_case_error)?;

        let asks = resolve_approval_policy(levels)
            == ApprovalPolicy::AskBeforeRiskyActions;
        let pushed_line = format!("Pushed 1 commit to {}", run.branch);
        let auto_pushed_line = format!("{pushed_line} (auto)");
        let expected_push_line = if asks {
            pushed_line
        } else {
            auto_pushed_line
        };
        prop_assert_eq!(run.approval_request_count, usize::from(asks));
        prop_assert!(
            run.log_lines.contains(&expected_push_line),
            "{:?}",
            run.log_lines
        );
        prop_assert_eq!(
            run.log_lines.contains(&AUTO_TOOLS_LINE.to_owned()),
            !asks
        );
    }
}
