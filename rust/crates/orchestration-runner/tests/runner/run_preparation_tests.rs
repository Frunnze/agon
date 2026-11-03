use std::fs;
use std::sync::Arc;

use orchestration_core::identifiers::SkillId;
use orchestration_core::library::{
    Skill, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::run::StepStatus;
use orchestration_core::scope::Scope;
use orchestration_core::task::Task;
use orchestration_core::workspace::AgentAccess;
use orchestration_hub::worktree_plan::plan_worktree;
use orchestration_runner::agents_file::AGENTS_FILE_NAME;
use orchestration_runner::run_executor::RunOutcome;
use orchestration_runner::worktree_request::describe_worktree_request;
use uuid::Uuid;

use crate::assignments::{
    assignment_for, claude_assignment, claude_task, rule_titled,
};
use crate::event_queries::{branches, failures, step_statuses};
use crate::executor_support::{
    RUN_NUMBER, execute_with_git_pusher, step_status_pairs,
};
use crate::fake_agent::{
    local_configuration, prepare_agent_folders, read_calls, read_prompt,
};
use crate::fake_server::FakeServer;
use crate::git_support::{create_bare_origin, repository_at};
use crate::support::TestResult;
use crate::workflows::{WorkflowShape, build_workflow};

fn skill_named(number: u128, name: &str, usage: SkillUsage) -> Skill {
    Skill {
        id: SkillId(Uuid::from_u128(number)),
        name: name.to_string(),
        summary: String::new(),
        instructions: format!("Instructions of {name}."),
        scope: Scope::everywhere(),
        usage,
        source: SkillSource::Created,
        improvement: SkillImprovement::Never,
        history: Vec::new(),
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn gives_the_agent_its_details_and_skills() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let task = Task {
        details: "Use the staging server.".to_string(),
        skills: vec![SkillId(Uuid::from_u128(1))],
        uses_automatic_skills: true,
        ..claude_task(RUN_NUMBER, "deploy-it")
    };
    let mut assignment = assignment_for(task, None, Vec::new(), RUN_NUMBER)?;
    assignment.skills = vec![
        skill_named(1, "deploy", SkillUsage::WhenChosen),
        skill_named(2, "style", SkillUsage::Automatic),
        skill_named(3, "unrelated", SkillUsage::WhenChosen),
    ];
    let server = Arc::new(FakeServer::with_queue(Vec::new()));

    execute_with_git_pusher(&server, &configuration, assignment).await?;

    let prompt = read_prompt(&folders, "deploy-it")?;
    assert!(prompt.starts_with("deploy-it"));
    assert!(prompt.contains("Use the staging server."));
    assert!(prompt.contains("Instructions of deploy."));
    assert!(prompt.contains("Instructions of style."));
    assert!(!prompt.contains("Instructions of unrelated."));
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn writes_the_rules_under_the_projects_agents_file() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let project_notes = ("AGENTS.md", "# Project\nUse pnpm.\n");
    let origin =
        create_bare_origin(folders.temporary.path(), "app", &[project_notes])?;
    let repository = repository_at(&origin, AgentAccess::PushAfterApproval);
    let task = claude_task(RUN_NUMBER, "fix-it");
    let mut assignment =
        assignment_for(task, None, vec![repository], RUN_NUMBER)?;
    assignment.rules = vec![
        rule_titled(1, "Never push to main", true),
        rule_titled(2, "Delete everything", false),
    ];
    let request = describe_worktree_request(
        &assignment,
        &configuration.worktree_roots,
        &configuration.clone_source,
    );
    let plan = plan_worktree(&request)?;
    let worktree = &plan.repositories.first().ok_or("no worktree")?.worktree;
    let run_id = assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));

    let first_outcome =
        execute_with_git_pusher(&server, &configuration, assignment.clone())
            .await?;
    let retried_outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let written = fs::read_to_string(worktree.join(AGENTS_FILE_NAME))?;
    let expected = "# Project\nUse pnpm.\n\n# Rules\n\n\
        - Never push to main.\n  Ask first.\n";
    assert_eq!(first_outcome, RunOutcome::Finished);
    assert_eq!(retried_outcome, RunOutcome::Finished);
    assert_eq!(written, expected);
    let expected_branches = vec![plan.branch.clone(), plan.branch.clone()];
    assert_eq!(branches(&server.events_of(run_id)), expected_branches);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn reports_an_assignment_it_cannot_run() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let mut assignment = claude_assignment(RUN_NUMBER, "fix-it")?;
    let shape = WorkflowShape {
        agent_count: 1,
        connections: Vec::new(),
        positions: Vec::new(),
        failing_agents: Vec::new(),
    };
    assignment.workflow = Some(build_workflow(&shape));
    let run_id = assignment.run.id;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));

    let outcome =
        execute_with_git_pusher(&server, &configuration, assignment).await?;

    let events = server.events_of(run_id);
    let reasons: Vec<String> = failures(&events)
        .into_iter()
        .map(|failure| failure.reason)
        .collect();
    let expected_reason = "the task runs one agent but a workflow was sent";
    assert_eq!(outcome, RunOutcome::Failed);
    assert_eq!(
        step_statuses(&events),
        step_status_pairs(&[StepStatus::Failed])
    );
    assert_eq!(reasons, vec![expected_reason.to_string()]);
    let no_calls: Vec<String> = Vec::new();
    assert_eq!(read_calls(&folders)?, no_calls);
    Ok(())
}
