use std::path::PathBuf;

use orchestration_core::identifiers::TaskId;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::worktree_plan::{
    WorktreeLifetime, WorktreePlan, WorktreeRequest, plan_worktree,
};
use proptest::prelude::*;
use serde_json::json;

pub const CACHE_ROOT: &str = "/runner/cache";
pub const WORKTREES_ROOT: &str = "/runner/worktrees";

pub fn any_task_id() -> impl Strategy<Value = TaskId> {
    any::<u128>().prop_filter_map("a task id parses", |number| {
        serde_json::from_value(json!(format!("{number:032x}"))).ok()
    })
}

pub fn any_lifetime() -> impl Strategy<Value = WorktreeLifetime> {
    prop_oneof![
        Just(WorktreeLifetime::PerTask),
        any::<u32>()
            .prop_map(|run_number| WorktreeLifetime::PerJobRun { run_number }),
    ]
}

pub fn any_hostile_title() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>(),
        Just("../../etc".to_string()),
        "(\\.\\./){1,4}[a-z]{0,5}",
        "[/\\\\.~ ]{0,10}",
        "[a-zA-Z0-9 ]{60,120}",
    ]
}

pub fn repository_at(address: &str) -> Repository {
    Repository {
        address: address.to_string(),
        default_branch: "main".to_string(),
        agent_access: AgentAccess::PushAfterApproval,
    }
}

pub fn request_for(
    task_id: TaskId,
    title: &str,
    lifetime: WorktreeLifetime,
    repositories: Vec<Repository>,
) -> WorktreeRequest {
    WorktreeRequest {
        task_id,
        task_title: title.to_string(),
        lifetime,
        repositories,
        cache_root: PathBuf::from(CACHE_ROOT),
        worktrees_root: PathBuf::from(WORKTREES_ROOT),
        clone_source: CloneSource::standard(),
    }
}

pub fn any_canonical_address() -> impl Strategy<Value = String> {
    "[a-z0-9-]{1,8}\\.[a-z]{2,4}/[a-zA-Z0-9_.-]{1,10}/[a-zA-Z0-9_.-]{1,12}"
        .prop_filter("the address is canonical", |address| {
            parse_repository_address(address).as_deref() == Ok(address)
        })
}

pub fn plan_or_fail(
    request: &WorktreeRequest,
) -> Result<WorktreePlan, TestCaseError> {
    plan_worktree(request)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}
