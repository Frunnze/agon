use orchestration_core::scope::Scope;
use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    DraftKind, DraftingContext, ItemDraft, ProjectDraft, RepositoryDraft,
    parse_item_answer,
};
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::drafting_samples::{
    context_strategy, describe_kind, kind_of, kind_strategy, valid_rule_draft,
    valid_skill_draft, valid_work_draft,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const ANSWER_CASES: u32 = 48;
const NO_JSON_OBJECT: &str = "the answer holds no JSON object";
const PLACE_FIELD: &str = "agent_place";

fn sample_draft(
    kind: DraftKind,
    context: &DraftingContext,
    words: &str,
) -> ItemDraft {
    match kind {
        DraftKind::Task => {
            ItemDraft::Task(valid_work_draft(context, words, words))
        }
        DraftKind::Job => {
            ItemDraft::Job(valid_work_draft(context, words, words))
        }
        DraftKind::Project => ItemDraft::Project(ProjectDraft {
            name: "billing".to_owned(),
            repositories: vec![RepositoryDraft {
                address: "https://github.com/acme/billing".to_owned(),
                default_branch: "main".to_owned(),
            }],
            agent_access: AgentAccess::ReadOnly,
        }),
        DraftKind::Skill => {
            ItemDraft::Skill(valid_skill_draft(context, "notes", words))
        }
        DraftKind::Rule => ItemDraft::Rule(valid_rule_draft(context, words)),
    }
}

fn answer_json(drafted: &ItemDraft) -> Result<Value, String> {
    let mut answer =
        serde_json::to_value(drafted).map_err(|error| error.to_string())?;
    let fields = answer.as_object_mut().ok_or("the draft is no object")?;
    fields.remove("kind");
    fields.insert("unknown_field".to_owned(), json!(["ignored"]));
    Ok(answer)
}

fn arbitrary_answer_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        "\\PC{0,200}",
        Just(String::from("{}")),
        Just(String::from("}{")),
        Just(String::from("{\"title\": 7}")),
        Just(String::from("```json\n{\"name\": \"x\"}\n```")),
    ]
}

#[test]
fn an_answer_without_json_names_the_kind_it_lacks() {
    let parsed = parse_item_answer(DraftKind::Task, "I could not do it");

    let Err(error) = parsed else {
        panic!("the answer is refused: {parsed:?}");
    };
    assert_eq!(
        error.to_string(),
        "the drafting agent did not answer with a task: the answer holds \
         no JSON object"
    );
}

#[test]
fn a_skill_answer_with_a_wrong_usage_is_refused() {
    let answer = json!({
        "name": "notes",
        "summary": "Notes",
        "instructions": "Write notes",
        "scope": Scope::everywhere(),
        "usage": "sometimes",
    });

    let parsed = parse_item_answer(DraftKind::Skill, &answer.to_string());

    let Err(error) = parsed else {
        panic!("the answer is refused: {parsed:?}");
    };
    let message = error.to_string();
    assert!(
        message
            .starts_with("the drafting agent did not answer with a skill: "),
        "{message}"
    );
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ANSWER_CASES))]

    #[test]
    fn test_parse_item_answer_property_a_wrong_place_is_refused(
        context in context_strategy(),
        is_job in any::<bool>(),
        words in "[a-z]{1,12}",
        wrong_place in prop_oneof![
            Just(Value::Null),
            Just(json!("anywhere")),
            Just(json!(1)),
        ],
    ) {
        let kind = if is_job { DraftKind::Job } else { DraftKind::Task };
        let drafted = sample_draft(kind, &context, &words);
        let mut answer = answer_json(&drafted).map_err(fail)?;
        let fields = answer
            .as_object_mut()
            .ok_or_else(|| TestCaseError::fail("the answer is no object"))?;
        fields.insert(PLACE_FIELD.to_owned(), wrong_place);

        let parsed = parse_item_answer(kind, &answer.to_string());

        let is_refused = matches!(parsed, Err(NodeError::DraftNotItem { .. }));
        prop_assert!(is_refused, "{:?}", parsed);
    }

    #[test]
    fn test_parse_item_answer_property_any_text_gets_a_defined_reply(
        kind in kind_strategy(),
        answer in arbitrary_answer_strategy(),
    ) {
        let parsed = parse_item_answer(kind, &answer);

        match parsed {
            Ok(drafted) => prop_assert_eq!(kind_of(&drafted), kind),
            Err(error) => {
                let is_draft_problem =
                    matches!(error, NodeError::DraftNotItem { .. });
                prop_assert!(is_draft_problem, "{}", error);
                let expected_start = format!(
                    "the drafting agent did not answer with a {}: ",
                    describe_kind(kind)
                );
                prop_assert!(error.to_string().starts_with(&expected_start));
            }
        }
    }

    #[test]
    fn test_parse_item_answer_property_reads_the_answer_out_of_prose(
        context in context_strategy(),
        kind in kind_strategy(),
        words in secret_text_strategy(),
    ) {
        let drafted = sample_draft(kind, &context, &words);
        let answer = answer_json(&drafted).map_err(fail)?;
        let final_message =
            format!("Here it is:\n```json\n{answer:#}\n```\nAll done.");

        let parsed = parse_item_answer(kind, &final_message).map_err(fail)?;

        prop_assert_eq!(parsed, drafted);
    }

    #[test]
    fn test_parse_item_answer_property_text_without_braces_holds_no_json(
        kind in kind_strategy(),
        answer in "[^{}]{0,120}",
    ) {
        let parsed = parse_item_answer(kind, &answer);

        let Err(error) = parsed else {
            return Err(TestCaseError::fail("text without braces parsed"));
        };
        let expected = format!(
            "the drafting agent did not answer with a {}: {NO_JSON_OBJECT}",
            describe_kind(kind)
        );
        prop_assert_eq!(error.to_string(), expected);
    }
}
