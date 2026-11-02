use serde::{Deserialize, Serialize};

use crate::identifiers::{ProjectId, WorkspaceId};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum WorkspaceScope {
    AllWorkspaces,
    OnlyWorkspaces { workspaces: Vec<WorkspaceId> },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ProjectScope {
    AllProjects,
    OnlyProjects { projects: Vec<ProjectId> },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Scope {
    pub workspaces: WorkspaceScope,
    pub projects: ProjectScope,
}

impl Scope {
    #[must_use]
    pub fn everywhere() -> Self {
        Self {
            workspaces: WorkspaceScope::AllWorkspaces,
            projects: ProjectScope::AllProjects,
        }
    }
}
