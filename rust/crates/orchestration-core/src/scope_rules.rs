use crate::identifiers::{ProjectId, WorkspaceId};
use crate::scope::{ProjectScope, Scope, WorkspaceScope};

#[must_use]
pub fn applies_to(
    scope: &Scope,
    workspace_id: WorkspaceId,
    project_id: ProjectId,
) -> bool {
    let includes_workspace =
        workspace_scope_includes(&scope.workspaces, workspace_id);
    let includes_project = project_scope_includes(&scope.projects, project_id);
    includes_workspace && includes_project
}

#[must_use]
pub fn workspace_scope_includes(
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

fn project_scope_includes(
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
