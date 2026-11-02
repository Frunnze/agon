use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::scope_rules::{applies_to, workspace_scope_includes};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::{
    project_identifier, scope, workspace_identifier, workspace_scope,
};

const MAXIMUM_FUZZ_ENTRIES: usize = 32;

fn is_workspace_listed(
    workspace_scope: &WorkspaceScope,
    workspace_id: WorkspaceId,
) -> bool {
    match workspace_scope {
        WorkspaceScope::AllWorkspaces => true,
        WorkspaceScope::OnlyWorkspaces { workspaces } => {
            workspaces.contains(&workspace_id)
        }
    }
}

fn is_project_listed(
    project_scope: &ProjectScope,
    project_id: ProjectId,
) -> bool {
    match project_scope {
        ProjectScope::AllProjects => true,
        ProjectScope::OnlyProjects { projects } => {
            projects.contains(&project_id)
        }
    }
}

proptest! {
    #[test]
    fn test_workspace_scope_includes_property_matches_listed_workspaces(
        workspace_scope in workspace_scope(),
        workspace_id in workspace_identifier(),
    ) {
        let expected = is_workspace_listed(&workspace_scope, workspace_id);

        let included =
            workspace_scope_includes(&workspace_scope, workspace_id);

        prop_assert_eq!(included, expected);
    }

    #[test]
    fn test_workspace_scope_includes_property_all_workspaces_include_any(
        workspace_id in workspace_identifier(),
    ) {
        let all_workspaces = WorkspaceScope::AllWorkspaces;

        prop_assert!(workspace_scope_includes(&all_workspaces, workspace_id));
    }

    #[test]
    fn test_applies_to_property_needs_both_workspace_and_project(
        scope in scope(),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let expected = is_workspace_listed(&scope.workspaces, workspace_id)
            && is_project_listed(&scope.projects, project_id);

        let applies = applies_to(&scope, workspace_id, project_id);

        prop_assert_eq!(applies, expected);
    }

    #[test]
    fn test_applies_to_property_everywhere_applies_to_any_project(
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let everywhere = Scope::everywhere();

        prop_assert!(applies_to(&everywhere, workspace_id, project_id));
    }

    #[test]
    fn test_applies_to_property_empty_lists_apply_nowhere(
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let nowhere = Scope {
            workspaces: WorkspaceScope::OnlyWorkspaces {
                workspaces: Vec::new(),
            },
            projects: ProjectScope::AllProjects,
        };

        prop_assert!(!applies_to(&nowhere, workspace_id, project_id));
    }

    #[test]
    fn test_applies_to_fuzz_arbitrary_identifiers_never_panic(
        workspace_numbers in vec(any::<u128>(), 0..MAXIMUM_FUZZ_ENTRIES),
        project_numbers in vec(any::<u128>(), 0..MAXIMUM_FUZZ_ENTRIES),
        workspace_number in any::<u128>(),
        project_number in any::<u128>(),
    ) {
        let workspaces: Vec<WorkspaceId> = workspace_numbers
            .iter()
            .map(|number| WorkspaceId(Uuid::from_u128(*number)))
            .collect();
        let projects: Vec<ProjectId> = project_numbers
            .iter()
            .map(|number| ProjectId(Uuid::from_u128(*number)))
            .collect();
        let workspace_id = WorkspaceId(Uuid::from_u128(workspace_number));
        let project_id = ProjectId(Uuid::from_u128(project_number));
        let scope = Scope {
            workspaces: WorkspaceScope::OnlyWorkspaces {
                workspaces: workspaces.clone(),
            },
            projects: ProjectScope::OnlyProjects {
                projects: projects.clone(),
            },
        };

        let applies = applies_to(&scope, workspace_id, project_id);

        let expected = workspaces.contains(&workspace_id)
            && projects.contains(&project_id);
        prop_assert_eq!(applies, expected);
    }
}
