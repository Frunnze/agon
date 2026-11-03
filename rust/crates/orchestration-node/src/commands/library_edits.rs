use chrono::Utc;
use orchestration_api::catalog::{SaveRuleRequest, SaveSkillRequest};
use orchestration_core::identifiers::{RuleId, SkillId, WorkspaceId};
use orchestration_core::library::{Rule, Skill, SkillSource, SkillUsage};
use orchestration_core::naming::validate_name;
use orchestration_core::scope::Scope;
use serde::Deserialize;
use serde_json::Value;

use super::workflow_skill_removal::remove_skill_from_workflows;
use crate::command_reply::encode_reply;
use crate::content_sealing::{open_rule, open_skill, seal_rule, seal_skill};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

pub(super) const LIBRARY_EDIT_COMMAND_NAMES: [&str; 4] =
    ["update_skill", "delete_skill", "update_rule", "delete_rule"];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum LibraryEditCommand {
    UpdateSkill {
        workspace_id: WorkspaceId,
        skill_id: SkillId,
        name: String,
        summary: String,
        instructions: String,
        scope: Scope,
        usage: SkillUsage,
    },
    DeleteSkill {
        skill_id: SkillId,
    },
    UpdateRule {
        workspace_id: WorkspaceId,
        rule_id: RuleId,
        title: String,
        details: String,
        scope: Scope,
    },
    DeleteRule {
        rule_id: RuleId,
    },
}

pub(super) async fn handle_library_edit_command(
    node: &Node,
    command: LibraryEditCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        LibraryEditCommand::UpdateSkill {
            workspace_id,
            skill_id,
            name,
            summary,
            instructions,
            scope,
            usage,
        } => {
            let skill = Skill {
                id: skill_id,
                name,
                summary,
                instructions,
                scope,
                usage,
                source: SkillSource::Created,
            };
            let stored =
                replace_skill(&session, &client, workspace_id, &skill).await?;
            encode_reply(&stored)
        }
        LibraryEditCommand::DeleteSkill { skill_id } => {
            client.delete_skill(skill_id).await?;
            remove_skill_from_workflows(&session, &client, skill_id).await?;
            Ok(Value::Null)
        }
        LibraryEditCommand::UpdateRule {
            workspace_id,
            rule_id,
            title,
            details,
            scope,
        } => {
            let rule = Rule {
                id: rule_id,
                title,
                details,
                scope,
                enabled: true,
                added_at: Utc::now(),
            };
            let stored =
                replace_rule(&session, &client, workspace_id, &rule).await?;
            encode_reply(&stored)
        }
        LibraryEditCommand::DeleteRule { rule_id } => {
            client.delete_rule(rule_id).await?;
            Ok(Value::Null)
        }
    }
}

pub(super) fn require_rule_title(title: &str) -> Result<(), NodeError> {
    if title.trim().is_empty() {
        return Err(NodeError::EmptyText { field: "rule" });
    }
    Ok(())
}

async fn replace_skill(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    skill: &Skill,
) -> Result<Skill, NodeError> {
    validate_name(&skill.name)?;
    let workspace_key = session.keyring.key_for(workspace_id)?;
    let request = SaveSkillRequest {
        skill: seal_skill(workspace_key, skill)?,
    };
    let stored = client.update_skill(skill.id, &request).await?;
    open_skill(&session.keyring, &stored)
}

async fn replace_rule(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    rule: &Rule,
) -> Result<Rule, NodeError> {
    require_rule_title(&rule.title)?;
    let workspace_key = session.keyring.key_for(workspace_id)?;
    let request = SaveRuleRequest {
        rule: seal_rule(workspace_key, rule)?,
    };
    let stored = client.update_rule(rule.id, &request).await?;
    open_rule(&session.keyring, &stored)
}
