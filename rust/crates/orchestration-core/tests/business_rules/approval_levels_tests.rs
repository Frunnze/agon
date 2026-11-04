use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::approval_levels::{
    ApprovalLevels, resolve_approval_policy,
};
use orchestration_core::task::Task;
use orchestration_core::workspace::{Project, Workspace};
use proptest::option;
use proptest::prelude::*;
use serde_json::Value;

use crate::entity_strategies::example_task;

fn store_task_without_policy() -> Result<Value, TestCaseError> {
    let mut stored = serde_json::to_value(example_task())
        .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
    let Some(fields) = stored.as_object_mut() else {
        return Err(TestCaseError::fail("a task is a JSON object"));
    };
    fields.remove("approval_policy");
    Ok(stored)
}

fn approval_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn approval_choice() -> impl Strategy<Value = Option<ApprovalPolicy>> {
    option::of(approval_policy())
}

proptest! {
    #[test]
    fn test_resolve_approval_policy_property_a_step_choice_always_wins(
        step in approval_policy(),
        project in approval_choice(),
        workspace in approval_policy(),
    ) {
        let levels = ApprovalLevels {
            step: Some(step),
            project,
            workspace,
        };

        prop_assert_eq!(resolve_approval_policy(levels), step);
    }

    #[test]
    fn test_resolve_approval_policy_property_project_wins_over_workspace(
        project in approval_policy(),
        workspace in approval_policy(),
    ) {
        let levels = ApprovalLevels {
            step: None,
            project: Some(project),
            workspace,
        };

        prop_assert_eq!(resolve_approval_policy(levels), project);
    }

    #[test]
    fn test_resolve_approval_policy_property_workspace_decides_the_rest(
        workspace in approval_policy(),
    ) {
        let levels = ApprovalLevels {
            step: None,
            project: None,
            workspace,
        };

        prop_assert_eq!(resolve_approval_policy(levels), workspace);
    }

    #[test]
    fn test_resolve_approval_policy_property_result_is_one_of_the_levels(
        step in approval_choice(),
        project in approval_choice(),
        workspace in approval_policy(),
    ) {
        let levels = ApprovalLevels { step, project, workspace };

        let resolved = resolve_approval_policy(levels);

        let chosen_levels = [step, project, Some(workspace)];
        prop_assert!(chosen_levels.contains(&Some(resolved)));
    }

    #[test]
    fn test_approval_policy_property_untouched_levels_resolve_to_auto(
        step in Just(None),
        project in Just(None),
    ) {
        let levels = ApprovalLevels {
            step,
            project,
            workspace: ApprovalPolicy::default(),
        };

        let resolved = resolve_approval_policy(levels);

        prop_assert_eq!(resolved, ApprovalPolicy::NeverAsk);
    }

    #[test]
    fn test_workspace_property_a_missing_policy_reads_as_auto(
        name in "[a-z]{1,12}",
    ) {
        let stored = serde_json::json!({
            "id": "6a4f0c56-3a33-4c55-9d43-4d4f6f6c0a01",
            "name": name,
            "app_server_address": "http://hub.local:7000",
        });

        let workspace: Workspace = serde_json::from_value(stored)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(workspace.approval_policy, ApprovalPolicy::NeverAsk);
    }

    #[test]
    fn test_project_property_a_missing_policy_follows_the_workspace(
        name in "[a-z]{1,12}",
    ) {
        let stored = serde_json::json!({
            "id": "6a4f0c56-3a33-4c55-9d43-4d4f6f6c0a02",
            "workspace_id": "6a4f0c56-3a33-4c55-9d43-4d4f6f6c0a01",
            "name": name,
            "repositories": [],
        });

        let project: Project = serde_json::from_value(stored)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(project.approval_policy, None);
    }

    #[test]
    fn test_project_property_a_stored_policy_is_kept(
        policy in approval_policy(),
    ) {
        let stored = serde_json::json!({
            "id": "6a4f0c56-3a33-4c55-9d43-4d4f6f6c0a02",
            "workspace_id": "6a4f0c56-3a33-4c55-9d43-4d4f6f6c0a01",
            "name": "shop",
            "repositories": [],
            "approval_policy": policy,
        });

        let project: Project = serde_json::from_value(stored)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(project.approval_policy, Some(policy));
    }

    #[test]
    fn test_task_property_a_stored_step_choice_is_kept(
        policy in approval_choice(),
    ) {
        let task = Task {
            approval_policy: policy,
            ..example_task()
        };

        let stored = serde_json::to_string(&task)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        let read_back: Task = serde_json::from_str(&stored)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(read_back.approval_policy, policy);
    }

    #[test]
    fn test_task_property_a_missing_choice_follows_the_project(
        title in "[a-z]{1,12}",
    ) {
        let mut stored = store_task_without_policy()?;
        stored["title"] = Value::String(title);

        let task: Task = serde_json::from_value(stored)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(task.approval_policy, None);
    }
}
