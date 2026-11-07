use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::scope_rules::{applies_to, workspace_scope_includes};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::entity_strategies::{
    project_identifier, project_scope, scope, workspace_identifier,
    workspace_scope,
};

const MOST_LISTED: usize = 4;

fn to_json(written_scope: &Scope) -> Result<Value, TestCaseError> {
    serde_json::to_value(written_scope)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn project_only(projects: ProjectScope) -> Scope {
    Scope {
        workspaces: WorkspaceScope::AllWorkspaces,
        projects,
    }
}

proptest! {
    #[test]
    fn test_scope_everywhere_property_applies_to_every_place(
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let everywhere = Scope::everywhere();

        prop_assert!(applies_to(&everywhere, workspace_id, project_id));
    }

    #[test]
    fn test_scope_everywhere_property_includes_whatever_any_scope_includes(
        any_scope in scope(),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        if applies_to(&any_scope, workspace_id, project_id) {
            let everywhere = Scope::everywhere();
            prop_assert!(applies_to(&everywhere, workspace_id, project_id));
        }
    }

    #[test]
    fn test_scope_everywhere_property_is_the_only_scope_written_as_all(
        any_scope in scope(),
    ) {
        let everywhere_written = to_json(&Scope::everywhere())?;
        let any_written = to_json(&any_scope)?;

        let expected = json!({
            "workspaces": { "kind": "all_workspaces" },
            "projects": { "kind": "all_projects" },
        });
        prop_assert_eq!(&everywhere_written, &expected);
        let is_everywhere = any_scope == Scope::everywhere();
        prop_assert_eq!(any_written == expected, is_everywhere);
    }

    #[test]
    fn test_workspace_scope_includes_property_listing_a_workspace_adds_it(
        listed_scope in workspace_scope(),
        workspace_id in workspace_identifier(),
        other_id in workspace_identifier(),
    ) {
        let WorkspaceScope::OnlyWorkspaces { workspaces } = listed_scope
        else {
            return Ok(());
        };
        let before = WorkspaceScope::OnlyWorkspaces {
            workspaces: workspaces.clone(),
        };
        let mut widened_list = workspaces;
        widened_list.push(workspace_id);
        let widened = WorkspaceScope::OnlyWorkspaces {
            workspaces: widened_list,
        };

        prop_assert!(workspace_scope_includes(&widened, workspace_id));
        if other_id != workspace_id {
            prop_assert_eq!(
                workspace_scope_includes(&widened, other_id),
                workspace_scope_includes(&before, other_id)
            );
        }
    }

    #[test]
    fn test_project_scope_includes_property_matches_listed_projects(
        projects in project_scope(),
        project_id in project_identifier(),
        workspace_id in workspace_identifier(),
    ) {
        let expected = match &projects {
            ProjectScope::AllProjects => true,
            ProjectScope::OnlyProjects { projects } => {
                projects.contains(&project_id)
            }
        };

        let only_projects = project_only(projects);
        let applies = applies_to(&only_projects, workspace_id, project_id);

        prop_assert_eq!(applies, expected);
    }

    #[test]
    fn test_project_scope_includes_property_all_projects_include_any(
        project_id in project_identifier(),
        workspace_id in workspace_identifier(),
    ) {
        let all = project_only(ProjectScope::AllProjects);

        prop_assert!(applies_to(&all, workspace_id, project_id));
    }

    #[test]
    fn test_project_scope_includes_property_ignores_list_order_and_repeats(
        projects in vec(project_identifier(), 0..MOST_LISTED),
        project_id in project_identifier(),
        workspace_id in workspace_identifier(),
    ) {
        let mut reordered = projects.clone();
        reordered.reverse();
        reordered.extend(projects.iter().copied());
        let listed = project_only(ProjectScope::OnlyProjects { projects });
        let repeated =
            project_only(ProjectScope::OnlyProjects { projects: reordered });

        prop_assert_eq!(
            applies_to(&repeated, workspace_id, project_id),
            applies_to(&listed, workspace_id, project_id)
        );
    }
}
