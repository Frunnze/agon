use orchestration_node::item_drafting::{
    DraftKind, check_item_draft, parse_item_answer, render_drafting_context,
};
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::draft_answer_samples::well_formed_answer;
use crate::support::draft_problem_texts::starts_with_review_label;
use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, context_strategy, foreign_uuid, kind_strategy,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const COMPLETENESS_CASES: u32 = 48;
const BREAKABLE_FIELD_COUNT: usize = 6;

type BrokenField = (&'static str, Value);

fn list_broken_fields(kind: DraftKind) -> Vec<BrokenField> {
    let foreign_id = foreign_uuid();
    let foreign_scope = json!({
        "workspaces": {"kind": "only_workspaces", "workspaces": [foreign_id]},
        "projects": {"kind": "only_projects", "projects": []},
    });
    match kind {
        DraftKind::Task | DraftKind::Job => vec![
            ("title", json!(" ")),
            ("project_id", json!(foreign_id)),
            (
                "doer",
                json!({"kind": "workflow", "workflow_id": foreign_id}),
            ),
            (
                "runs_on",
                json!({
                    "kind": "specific_runner",
                    "device_id": FOREIGN_DEVICE_ID,
                }),
            ),
            ("skills", json!([foreign_id])),
            ("schedule", json!({"every": "hour", "minute": 75})),
        ],
        DraftKind::Project => vec![
            ("name", json!("Mobile App")),
            ("repositories", json!([])),
            (
                "repositories",
                json!([{
                    "address": "ftp://github.com/a/b",
                    "default_branch": "main",
                }]),
            ),
        ],
        DraftKind::Skill => vec![
            ("name", json!("Notes")),
            ("summary", json!("")),
            ("instructions", json!(" ")),
            ("scope", foreign_scope),
        ],
        DraftKind::Rule => {
            vec![("title", json!("")), ("scope", foreign_scope)]
        }
    }
}

fn break_answer(kind: DraftKind, answer: &mut Value, chosen: &[bool]) {
    let Some(fields) = answer.as_object_mut() else {
        return;
    };
    for (index, (field, broken_value)) in
        list_broken_fields(kind).into_iter().enumerate()
    {
        if chosen.get(index).copied().unwrap_or_default() {
            fields.insert(field.to_owned(), broken_value);
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COMPLETENESS_CASES))]

    #[test]
    fn test_check_item_draft_property_a_well_formed_answer_is_complete(
        context in context_strategy(),
        kind in kind_strategy(),
        words in secret_text_strategy(),
    ) {
        let answer = well_formed_answer(kind, &context, &words);

        let drafted =
            parse_item_answer(kind, &answer.to_string()).map_err(fail)?;
        let checked = check_item_draft(&context, &drafted);

        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_check_item_draft_property_each_problem_starts_with_its_label(
        context in context_strategy(),
        kind in kind_strategy(),
        words in secret_text_strategy(),
        chosen in proptest::collection::vec(
            any::<bool>(),
            BREAKABLE_FIELD_COUNT,
        ),
    ) {
        let mut answer = well_formed_answer(kind, &context, &words);
        break_answer(kind, &mut answer, &chosen);

        let drafted =
            parse_item_answer(kind, &answer.to_string()).map_err(fail)?;
        let checked = check_item_draft(&context, &drafted);

        let breakable_count = list_broken_fields(kind).len();
        let is_broken = chosen
            .iter()
            .take(breakable_count)
            .any(|is_chosen| *is_chosen);
        prop_assert_eq!(!checked.problems.is_empty(), is_broken);
        for problem in &checked.problems {
            let is_labelled = starts_with_review_label(kind, problem);
            prop_assert!(is_labelled, "{}", problem);
            prop_assert!(problem.contains(". Ask for changes and "));
        }
    }

    #[test]
    fn test_render_drafting_context_property_skill_usage_is_a_field_value(
        context in context_strategy(),
    ) {
        let rendered = render_drafting_context(&context);

        prop_assert!(!rendered.contains("when chosen"), "{}", rendered);
        for skill in &context.skills {
            let skill_id_marker = format!("(id {}), ", skill.id.0);
            let line = rendered
                .lines()
                .find(|line| line.contains(&skill_id_marker))
                .unwrap_or_default();
            let names_a_usage = line.contains("), when_chosen: ")
                || line.contains("), automatic: ");
            prop_assert!(names_a_usage, "{}", line);
        }
    }
}
