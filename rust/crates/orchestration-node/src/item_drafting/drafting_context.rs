use orchestration_core::agent_place::AgentPlace;
use orchestration_core::identifiers::{
    DeviceId, ProjectId, SkillId, WorkflowId, WorkspaceId,
};
use orchestration_core::library::SkillUsage;
use orchestration_core::workspace::Project;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DraftingWorkspace {
    pub id: WorkspaceId,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DraftingDevice {
    pub id: DeviceId,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DraftingWorkflow {
    pub id: WorkflowId,
    pub name: String,
    pub is_signed: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DraftingSkill {
    pub id: SkillId,
    pub name: String,
    pub summary: String,
    pub usage: SkillUsage,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DraftingRunner {
    pub device: DraftingDevice,
    pub is_online: bool,
    pub labels: Vec<String>,
    pub offers: Vec<AgentPlace>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DraftingContext {
    pub workspace: DraftingWorkspace,
    pub this_device: DraftingDevice,
    pub projects: Vec<Project>,
    pub workflows: Vec<DraftingWorkflow>,
    pub skills: Vec<DraftingSkill>,
    pub runners: Vec<DraftingRunner>,
}

impl DraftingContext {
    pub(super) fn includes_project(&self, project_id: ProjectId) -> bool {
        self.projects.iter().any(|project| project.id == project_id)
    }
}
