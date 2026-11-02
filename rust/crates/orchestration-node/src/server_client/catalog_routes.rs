use orchestration_api::catalog::{
    AddRepositoryRequest, RemoveRepositoryRequest, SaveProjectRequest,
    SaveRuleRequest, SaveSkillRequest, SaveWorkflowRequest,
    SetRuleEnabledRequest, SignWorkflowRequest, WorkflowListing,
};
use orchestration_api::routes::{
    PROJECT_REPOSITORIES, PROJECTS, RULE, RULE_ENABLED, RULES, SKILL, SKILLS,
    WORKFLOW, WORKFLOW_DISCARD, WORKFLOW_SIGNATURE, WORKFLOWS,
};
use orchestration_core::identifiers::{
    ProjectId, RuleId, SkillId, WorkflowId,
};
use orchestration_core::library::{Rule, Skill};
use orchestration_core::workspace::Project;
use reqwest::Method;

use super::route_paths::fill_route;
use super::signed_server_client::SignedServerClient;
use crate::node_error::NodeError;

const PROJECT_PLACEHOLDER: &str = "project_id";
const WORKFLOW_PLACEHOLDER: &str = "workflow_id";
const RULE_PLACEHOLDER: &str = "rule_id";
const SKILL_PLACEHOLDER: &str = "skill_id";

impl SignedServerClient<'_> {
    pub async fn list_projects(&self) -> Result<Vec<Project>, NodeError> {
        self.fetch(PROJECTS).await
    }

    pub async fn save_project(
        &self,
        request: &SaveProjectRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::POST, PROJECTS, request).await
    }

    pub async fn add_repository(
        &self,
        project_id: ProjectId,
        request: &AddRepositoryRequest,
    ) -> Result<(), NodeError> {
        let project_text = project_id.0.to_string();
        let path = fill_route(
            PROJECT_REPOSITORIES,
            &[(PROJECT_PLACEHOLDER, &project_text)],
        )?;
        self.submit(Method::POST, &path, request).await
    }

    pub async fn remove_repository(
        &self,
        project_id: ProjectId,
        request: &RemoveRepositoryRequest,
    ) -> Result<Project, NodeError> {
        let project_text = project_id.0.to_string();
        let path = fill_route(
            PROJECT_REPOSITORIES,
            &[(PROJECT_PLACEHOLDER, &project_text)],
        )?;
        self.exchange(Method::DELETE, &path, request).await
    }

    pub async fn list_workflows(
        &self,
    ) -> Result<Vec<WorkflowListing>, NodeError> {
        self.fetch(WORKFLOWS).await
    }

    pub async fn create_workflow(
        &self,
        request: &SaveWorkflowRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::POST, WORKFLOWS, request).await
    }

    pub async fn update_workflow(
        &self,
        workflow_id: WorkflowId,
        request: &SaveWorkflowRequest,
    ) -> Result<(), NodeError> {
        let path = fill_workflow_route(WORKFLOW, workflow_id)?;
        self.submit(Method::PUT, &path, request).await
    }

    pub async fn sign_workflow(
        &self,
        workflow_id: WorkflowId,
        request: &SignWorkflowRequest,
    ) -> Result<(), NodeError> {
        let path = fill_workflow_route(WORKFLOW_SIGNATURE, workflow_id)?;
        self.submit(Method::POST, &path, request).await
    }

    pub async fn discard_workflow_change(
        &self,
        workflow_id: WorkflowId,
    ) -> Result<(), NodeError> {
        let path = fill_workflow_route(WORKFLOW_DISCARD, workflow_id)?;
        self.submit_without_body(Method::POST, &path).await?;
        Ok(())
    }

    pub async fn list_skills(&self) -> Result<Vec<Skill>, NodeError> {
        self.fetch(SKILLS).await
    }

    pub async fn save_skill(
        &self,
        request: &SaveSkillRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::POST, SKILLS, request).await
    }

    pub async fn update_skill(
        &self,
        skill_id: SkillId,
        request: &SaveSkillRequest,
    ) -> Result<Skill, NodeError> {
        let path = fill_skill_route(skill_id)?;
        self.exchange(Method::PUT, &path, request).await
    }

    pub async fn delete_skill(
        &self,
        skill_id: SkillId,
    ) -> Result<(), NodeError> {
        let path = fill_skill_route(skill_id)?;
        self.submit_without_body(Method::DELETE, &path).await?;
        Ok(())
    }

    pub async fn list_rules(&self) -> Result<Vec<Rule>, NodeError> {
        self.fetch(RULES).await
    }

    pub async fn save_rule(
        &self,
        request: &SaveRuleRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::POST, RULES, request).await
    }

    pub async fn update_rule(
        &self,
        rule_id: RuleId,
        request: &SaveRuleRequest,
    ) -> Result<Rule, NodeError> {
        let path = fill_rule_route(RULE, rule_id)?;
        self.exchange(Method::PUT, &path, request).await
    }

    pub async fn delete_rule(&self, rule_id: RuleId) -> Result<(), NodeError> {
        let path = fill_rule_route(RULE, rule_id)?;
        self.submit_without_body(Method::DELETE, &path).await?;
        Ok(())
    }

    pub async fn set_rule_enabled(
        &self,
        rule_id: RuleId,
        request: &SetRuleEnabledRequest,
    ) -> Result<(), NodeError> {
        let path = fill_rule_route(RULE_ENABLED, rule_id)?;
        self.submit(Method::PUT, &path, request).await
    }
}

fn fill_workflow_route(
    template: &str,
    workflow_id: WorkflowId,
) -> Result<String, NodeError> {
    let workflow_text = workflow_id.0.to_string();
    fill_route(template, &[(WORKFLOW_PLACEHOLDER, &workflow_text)])
}

fn fill_skill_route(skill_id: SkillId) -> Result<String, NodeError> {
    let skill_text = skill_id.0.to_string();
    fill_route(SKILL, &[(SKILL_PLACEHOLDER, &skill_text)])
}

fn fill_rule_route(
    template: &str,
    rule_id: RuleId,
) -> Result<String, NodeError> {
    let rule_text = rule_id.0.to_string();
    fill_route(template, &[(RULE_PLACEHOLDER, &rule_text)])
}
