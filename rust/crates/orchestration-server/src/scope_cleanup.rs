use std::collections::BTreeSet;

use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};

use crate::stored_state::StoredState;

pub fn forget_projects_in_scopes(
    state: &mut StoredState,
    project_ids: &BTreeSet<ProjectId>,
) {
    for skill in state.skills.values_mut() {
        skill.scope = without_projects(&skill.scope, project_ids);
    }
    for rule in state.rules.values_mut() {
        rule.scope = without_projects(&rule.scope, project_ids);
    }
}

pub fn forget_workspace_in_scopes(
    state: &mut StoredState,
    workspace_id: WorkspaceId,
) {
    for skill in state.skills.values_mut() {
        skill.scope = without_workspace(&skill.scope, workspace_id);
    }
    for rule in state.rules.values_mut() {
        rule.scope = without_workspace(&rule.scope, workspace_id);
    }
}

fn without_projects(
    scope: &Scope,
    project_ids: &BTreeSet<ProjectId>,
) -> Scope {
    let projects = match &scope.projects {
        ProjectScope::AllProjects => ProjectScope::AllProjects,
        ProjectScope::OnlyProjects { projects } => {
            let kept_projects = projects
                .iter()
                .filter(|project_id| !project_ids.contains(project_id))
                .copied()
                .collect();
            ProjectScope::OnlyProjects {
                projects: kept_projects,
            }
        }
    };
    Scope {
        workspaces: scope.workspaces.clone(),
        projects,
    }
}

fn without_workspace(scope: &Scope, workspace_id: WorkspaceId) -> Scope {
    let workspaces = match &scope.workspaces {
        WorkspaceScope::AllWorkspaces => WorkspaceScope::AllWorkspaces,
        WorkspaceScope::OnlyWorkspaces { workspaces } => {
            let kept_workspaces = workspaces
                .iter()
                .filter(|listed_id| **listed_id != workspace_id)
                .copied()
                .collect();
            WorkspaceScope::OnlyWorkspaces {
                workspaces: kept_workspaces,
            }
        }
    };
    Scope {
        workspaces,
        projects: scope.projects.clone(),
    }
}
