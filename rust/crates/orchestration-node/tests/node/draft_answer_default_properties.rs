use orchestration_core::agent_place::AgentPlace;
use orchestration_core::device::RunnerTarget;
use orchestration_core::library::SkillImprovement;
use orchestration_core::naming::convert_to_project_name;
use orchestration_core::scope::Scope;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::AgentKind;
use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    DraftKind, ItemDraft, WorkDraft, check_item_draft, parse_item_answer,
};
use proptest::prelude::*;
use serde_json::{Map, Value, json};

use crate::support::draft_answer_samples::well_formed_work;
use crate::support::drafting_samples::{context_strategy, empty_context};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const DEFAULT_CASES: u32 = 48;
const REPOSITORY_NAME_PATTERN: &str = "[A-Za-z0-9][A-Za-z0-9_-]{0,12}";
const BLANK_NAMES: [&str; 2] = ["", "  "];
const DEFAULTED_WORK_FIELDS: [&str; 7] = [
    "details",
    "doer",
    "runs_on",
    "agent_place",
    "skills",
    "uses_automatic_skills",
    "approval_policy",
];

fn remove_fields(answer: &mut Value, removed: &[bool]) -> Vec<&'static str> {
    let mut removed_fields = Vec::new();
    let Some(fields) = answer.as_object_mut() else {
        return removed_fields;
    };
    for (index, field) in DEFAULTED_WORK_FIELDS.into_iter().enumerate() {
        if removed.get(index).copied().unwrap_or_default() {
            fields.remove(field);
            removed_fields.push(field);
        }
    }
    removed_fields
}

fn fill_form_default(work: WorkDraft, field: &str) -> WorkDraft {
    match field {
        "details" => WorkDraft {
            details: String::new(),
            ..work
        },
        "doer" => WorkDraft {
            doer: TaskDoer::OneAgent {
                agent: AgentKind::ClaudeCode,
            },
            ..work
        },
        "runs_on" => WorkDraft {
            runs_on: RunnerTarget::AnyFreeRunner,
            ..work
        },
        "agent_place" => WorkDraft {
            agent_place: AgentPlace::LocalProcess,
            ..work
        },
        "skills" => WorkDraft {
            skills: Vec::new(),
            ..work
        },
        "uses_automatic_skills" => WorkDraft {
            uses_automatic_skills: true,
            ..work
        },
        _ => WorkDraft {
            approval_policy: None,
            ..work
        },
    }
}

fn parse_work(kind: DraftKind, answer: &Value) -> Result<WorkDraft, String> {
    match parse_item_answer(kind, &answer.to_string()) {
        Ok(ItemDraft::Task(work) | ItemDraft::Job(work)) => Ok(work),
        other => Err(format!("no work draft: {other:?}")),
    }
}

fn work_kind_strategy() -> impl Strategy<Value = DraftKind> {
    prop_oneof![Just(DraftKind::Task), Just(DraftKind::Job)]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DEFAULT_CASES))]

    #[test]
    fn test_parse_item_answer_property_missing_fields_take_form_defaults(
        context in context_strategy(),
        kind in work_kind_strategy(),
        words in secret_text_strategy(),
        removed in proptest::collection::vec(
            any::<bool>(),
            DEFAULTED_WORK_FIELDS.len(),
        ),
    ) {
        let complete = well_formed_work(&context, &words);
        let mut answer = complete.clone();
        let removed_fields = remove_fields(&mut answer, &removed);

        let parsed = parse_work(kind, &answer).map_err(fail)?;

        let mut expected = parse_work(kind, &complete).map_err(fail)?;
        for field in removed_fields {
            expected = fill_form_default(expected, field);
        }
        prop_assert_eq!(parsed, expected);
    }

    #[test]
    fn test_parse_item_answer_property_optional_library_fields_default(
        name in "[a-z]{3,8}",
        words in secret_text_strategy(),
    ) {
        let project = json!({
            "name": name,
            "repositories": [],
        });
        let mut rule = Map::new();
        rule.insert("title".to_owned(), json!(words));
        rule.insert("scope".to_owned(), json!({
            "workspaces": {"kind": "all_workspaces"},
            "projects": {"kind": "all_projects"},
        }));

        let parsed_project =
            parse_item_answer(DraftKind::Project, &project.to_string())
                .map_err(fail)?;
        let rule_answer = Value::Object(rule).to_string();
        let parsed_rule =
            parse_item_answer(DraftKind::Rule, &rule_answer).map_err(fail)?;

        let ItemDraft::Project(project_draft) = parsed_project else {
            return Err(TestCaseError::fail("no project draft"));
        };
        prop_assert_eq!(
            project_draft.agent_access,
            AgentAccess::PushAfterApproval
        );
        prop_assert_eq!(project_draft.approval_policy, None);
        let ItemDraft::Rule(rule_draft) = parsed_rule else {
            return Err(TestCaseError::fail("no rule draft"));
        };
        prop_assert_eq!(rule_draft.details, "");
    }

    #[test]
    fn test_check_item_draft_property_a_missing_name_follows_the_first_repo(
        repository_name in REPOSITORY_NAME_PATTERN,
        blank_name in proptest::sample::select(BLANK_NAMES.to_vec()),
        is_name_left_out in any::<bool>(),
    ) {
        let first_address = format!("github.com/acme/{repository_name}");
        let repositories = json!([
            {"address": first_address, "default_branch": "main"},
            {"address": "github.com/acme/other", "default_branch": "main"},
        ]);
        let answer = if is_name_left_out {
            json!({ "repositories": repositories })
        } else {
            json!({ "name": blank_name, "repositories": repositories })
        };

        let parsed = parse_item_answer(DraftKind::Project, &answer.to_string())
            .map_err(fail)?;
        let checked = check_item_draft(&empty_context(), &parsed);

        let ItemDraft::Project(project) = checked.draft else {
            return Err(TestCaseError::fail("no project draft"));
        };
        prop_assert_eq!(
            project.name,
            convert_to_project_name(&repository_name)
        );
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_parse_item_answer_property_a_new_skill_improves_on_auto(
        name in "[a-z]{3,8}",
        words in secret_text_strategy(),
    ) {
        let skill = json!({
            "name": name,
            "summary": words,
            "instructions": words,
            "scope": Scope::everywhere(),
            "usage": "automatic",
        });

        let parsed = parse_item_answer(DraftKind::Skill, &skill.to_string())
            .map_err(fail)?;

        let ItemDraft::Skill(skill_draft) = parsed else {
            return Err(TestCaseError::fail("no skill draft"));
        };
        prop_assert_eq!(skill_draft.improvement, SkillImprovement::Auto);
    }
}
