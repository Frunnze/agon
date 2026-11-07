use chrono::Utc;
use orchestration_api::catalog::{
    SaveRuleRequest, SaveSkillRequest, SetRuleEnabledRequest,
};
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::identifiers::{
    ProjectId, RuleId, SkillId, WorkspaceId, generate_uuid,
};
use orchestration_core::library::{
    Rule, Skill, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::naming::validate_name;
use orchestration_core::rule_titles::validate_rule_title;
use orchestration_core::scope::Scope;
use orchestration_core::scope_rules::workspace_scope_includes;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::command_reply::encode_reply;
use crate::content_sealing::{open_rule, open_skill, seal_rule, seal_skill};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

pub(super) const LIBRARY_COMMAND_NAMES: [&str; 6] = [
    "list_skills",
    "create_skill",
    "list_rules",
    "create_rule",
    "set_rule_enabled",
    "show_agents_markdown",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum LibraryCommand {
    ListSkills {
        workspace_id: WorkspaceId,
    },
    CreateSkill {
        workspace_id: WorkspaceId,
        name: String,
        summary: String,
        instructions: String,
        scope: Scope,
        usage: SkillUsage,
        improvement: SkillImprovement,
    },
    ListRules {
        workspace_id: WorkspaceId,
    },
    CreateRule {
        workspace_id: WorkspaceId,
        title: String,
        details: String,
        scope: Scope,
    },
    SetRuleEnabled {
        rule_id: RuleId,
        enabled: bool,
    },
    ShowAgentsMarkdown {
        workspace_id: WorkspaceId,
        project_id: ProjectId,
    },
}

#[derive(Debug, Serialize)]
struct AgentsMarkdownView {
    markdown: String,
}

pub(super) async fn handle_library_command(
    node: &Node,
    command: LibraryCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        LibraryCommand::ListSkills { workspace_id } => {
            let mut usable_skills = Vec::new();
            for skill in client.list_skills().await? {
                if workspace_scope_includes(
                    &skill.scope.workspaces,
                    workspace_id,
                ) {
                    usable_skills.push(open_skill(&session.keyring, &skill)?);
                }
            }
            encode_reply(&usable_skills)
        }
        LibraryCommand::CreateSkill {
            workspace_id,
            name,
            summary,
            instructions,
            scope,
            usage,
            improvement,
        } => {
            validate_name(&name)?;
            let skill = Skill {
                id: SkillId(generate_uuid()),
                name,
                summary,
                instructions,
                scope,
                usage,
                source: SkillSource::Created,
                improvement,
                history: Vec::new(),
            };
            let workspace_key = session.keyring.key_for(workspace_id)?;
            let sealed_skill = seal_skill(workspace_key, &skill)?;
            let request = SaveSkillRequest {
                skill: sealed_skill,
            };
            client.save_skill(&request).await?;
            encode_reply(&skill)
        }
        LibraryCommand::ListRules { workspace_id } => encode_reply(
            &list_rules_in(&session, &client, workspace_id).await?,
        ),
        LibraryCommand::CreateRule {
            workspace_id,
            title,
            details,
            scope,
        } => encode_reply(
            &create_rule(
                &session,
                &client,
                workspace_id,
                title,
                details,
                scope,
            )
            .await?,
        ),
        LibraryCommand::SetRuleEnabled { rule_id, enabled } => {
            let request = SetRuleEnabledRequest { enabled };
            client.set_rule_enabled(rule_id, &request).await?;
            Ok(Value::Null)
        }
        LibraryCommand::ShowAgentsMarkdown {
            workspace_id,
            project_id,
        } => {
            let rules = list_rules_in(&session, &client, workspace_id).await?;
            let markdown =
                render_agents_markdown(&rules, workspace_id, project_id);
            encode_reply(&AgentsMarkdownView { markdown })
        }
    }
}

async fn list_rules_in(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
) -> Result<Vec<Rule>, NodeError> {
    let mut usable_rules = Vec::new();
    for rule in client.list_rules().await? {
        if workspace_scope_includes(&rule.scope.workspaces, workspace_id) {
            usable_rules.push(open_rule(&session.keyring, &rule)?);
        }
    }
    Ok(usable_rules)
}

async fn create_rule(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    title: String,
    details: String,
    scope: Scope,
) -> Result<Rule, NodeError> {
    validate_rule_title(&title)?;
    let rule = Rule {
        id: RuleId(generate_uuid()),
        title,
        details,
        scope,
        enabled: true,
        added_at: Utc::now(),
    };
    let workspace_key = session.keyring.key_for(workspace_id)?;
    let request = SaveRuleRequest {
        rule: seal_rule(workspace_key, &rule)?,
    };
    client.save_rule(&request).await?;
    Ok(rule)
}
