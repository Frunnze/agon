use orchestration_core::identifiers::{ProjectId, SkillId, WorkspaceId};
use orchestration_core::library::SkillUsage;
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_node::item_drafting::{
    DraftingContext, DraftingSkill, ItemDraft, RuleDraft, SkillDraft,
    check_item_draft,
};
use proptest::prelude::*;

use crate::support::draft_problem_texts::{join_choices, list_project_names};
use crate::support::drafting_samples::{
    context_strategy, foreign_uuid, padded, valid_rule_draft,
    valid_skill_draft,
};
use crate::support::entity_strategies::secret_text_strategy;

const LIBRARY_CASES: u32 = 32;
const SKILL_NAME_PATTERN: &str = "[a-z]{3,8}";
const TAKEN_SKILL_NAME: &str = "taken";
const EMPTY_SCOPE: &str =
    "Applies to: it is empty. Ask for changes and say where it applies.";
const FOREIGN_WORKSPACE: &str = "Applies to: the chosen workspace does not \
                                 exist here. Ask for changes and say this \
                                 workspace or everywhere.";
const EMPTY_RULE_TITLE: &str = "Rule: it is empty. Ask for changes and say \
                                what agents must follow.";

#[derive(Clone, Copy, Debug)]
enum ScopeDefect {
    ForeignWorkspace,
    ForeignProject,
    EmptyWorkspaceList,
    EmptyProjectList,
}

#[derive(Clone, Copy, Debug)]
enum SkillDefect {
    InvalidName,
    TakenName,
    EmptySummary,
    EmptyInstructions,
    Scope(ScopeDefect),
}

fn scope_defect_strategy() -> impl Strategy<Value = ScopeDefect> {
    prop_oneof![
        Just(ScopeDefect::ForeignWorkspace),
        Just(ScopeDefect::ForeignProject),
        Just(ScopeDefect::EmptyWorkspaceList),
        Just(ScopeDefect::EmptyProjectList),
    ]
}

fn skill_defect_strategy() -> impl Strategy<Value = SkillDefect> {
    prop_oneof![
        Just(SkillDefect::InvalidName),
        Just(SkillDefect::TakenName),
        Just(SkillDefect::EmptySummary),
        Just(SkillDefect::EmptyInstructions),
        scope_defect_strategy().prop_map(SkillDefect::Scope),
    ]
}

fn describe_foreign_project(context: &DraftingContext) -> String {
    format!(
        "Applies to: a chosen project is not in acme. Ask for changes and \
         name one of: {}.",
        join_choices(list_project_names(context), "all projects")
    )
}

fn apply_scope_defect(
    context: &DraftingContext,
    scope: &mut Scope,
    defect: ScopeDefect,
) -> String {
    match defect {
        ScopeDefect::ForeignWorkspace => {
            scope.workspaces = WorkspaceScope::OnlyWorkspaces {
                workspaces: vec![WorkspaceId(foreign_uuid())],
            };
            FOREIGN_WORKSPACE.to_owned()
        }
        ScopeDefect::ForeignProject => {
            scope.projects = ProjectScope::OnlyProjects {
                projects: vec![ProjectId(foreign_uuid())],
            };
            describe_foreign_project(context)
        }
        ScopeDefect::EmptyWorkspaceList => {
            scope.workspaces = WorkspaceScope::OnlyWorkspaces {
                workspaces: Vec::new(),
            };
            EMPTY_SCOPE.to_owned()
        }
        ScopeDefect::EmptyProjectList => {
            scope.projects = ProjectScope::OnlyProjects {
                projects: Vec::new(),
            };
            EMPTY_SCOPE.to_owned()
        }
    }
}

fn apply_skill_defect(
    context: &mut DraftingContext,
    skill: &mut SkillDraft,
    defect: SkillDefect,
) -> String {
    match defect {
        SkillDefect::InvalidName => {
            "Notes".clone_into(&mut skill.name);
            "Name: a name can only use lowercase letters, digits and dashes, \
             not 'N'. Ask for changes and give another name."
                .to_owned()
        }
        SkillDefect::TakenName => {
            context.skills.push(DraftingSkill {
                id: SkillId(foreign_uuid()),
                name: TAKEN_SKILL_NAME.to_owned(),
                summary: "Already here".to_owned(),
                usage: SkillUsage::Automatic,
            });
            skill.name = padded(TAKEN_SKILL_NAME);
            format!(
                "Name: a skill named {TAKEN_SKILL_NAME} already exists. Ask \
                 for changes and give another name."
            )
        }
        SkillDefect::EmptySummary => {
            "  ".clone_into(&mut skill.summary);
            "What it does: it is empty. Ask for changes and say what the \
             skill does."
                .to_owned()
        }
        SkillDefect::EmptyInstructions => {
            "\n".clone_into(&mut skill.instructions);
            "Instructions: they are empty. Ask for changes and say what \
             agents should do."
                .to_owned()
        }
        SkillDefect::Scope(scope_defect) => {
            apply_scope_defect(context, &mut skill.scope, scope_defect)
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LIBRARY_CASES))]

    #[test]
    fn test_check_item_draft_property_valid_skill_is_kept_trimmed(
        context in context_strategy(),
        name in SKILL_NAME_PATTERN,
        words in secret_text_strategy(),
    ) {
        let trimmed = valid_skill_draft(&context, &name, &words);
        let answered = SkillDraft {
            name: padded(&trimmed.name),
            summary: padded(&trimmed.summary),
            instructions: padded(&trimmed.instructions),
            ..trimmed.clone()
        };

        let checked = check_item_draft(&context, &ItemDraft::Skill(answered));

        prop_assert_eq!(checked.draft, ItemDraft::Skill(trimmed));
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_check_item_draft_property_each_skill_defect_gives_its_sentence(
        context in context_strategy(),
        name in SKILL_NAME_PATTERN,
        words in secret_text_strategy(),
        defect in skill_defect_strategy(),
    ) {
        let mut context = context;
        let mut skill = valid_skill_draft(&context, &name, &words);
        let expected = apply_skill_defect(&mut context, &mut skill, defect);

        let checked = check_item_draft(&context, &ItemDraft::Skill(skill));

        prop_assert_eq!(checked.problems, vec![expected]);
    }

    #[test]
    fn test_check_item_draft_property_valid_rule_is_kept_trimmed(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let trimmed = valid_rule_draft(&context, &words);
        let answered = RuleDraft {
            title: padded(&trimmed.title),
            details: padded(&trimmed.details),
            ..trimmed.clone()
        };

        let checked = check_item_draft(&context, &ItemDraft::Rule(answered));

        prop_assert_eq!(checked.draft, ItemDraft::Rule(trimmed));
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_check_item_draft_property_each_rule_defect_gives_its_sentence(
        context in context_strategy(),
        words in secret_text_strategy(),
        scope_defect in proptest::option::of(scope_defect_strategy()),
    ) {
        let mut rule = valid_rule_draft(&context, &words);
        let expected = if let Some(scope_defect) = scope_defect {
            apply_scope_defect(&context, &mut rule.scope, scope_defect)
        } else {
            " ".clone_into(&mut rule.title);
            EMPTY_RULE_TITLE.to_owned()
        };

        let checked = check_item_draft(&context, &ItemDraft::Rule(rule));

        prop_assert_eq!(checked.problems, vec![expected]);
    }

    #[test]
    fn test_check_item_draft_property_scope_problems_follow_field_order(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut rule = valid_rule_draft(&context, &words);
        rule.title = String::new();
        let empty_both = [
            ScopeDefect::EmptyWorkspaceList,
            ScopeDefect::EmptyProjectList,
        ];
        for scope_defect in empty_both {
            apply_scope_defect(&context, &mut rule.scope, scope_defect);
        }

        let checked = check_item_draft(&context, &ItemDraft::Rule(rule));

        let expected =
            vec![EMPTY_RULE_TITLE.to_owned(), EMPTY_SCOPE.to_owned()];
        prop_assert_eq!(checked.problems, expected);
    }

    #[test]
    fn test_check_item_draft_property_foreign_workspace_and_empty_projects(
        context in context_strategy(),
        name in SKILL_NAME_PATTERN,
        words in secret_text_strategy(),
    ) {
        let mut skill = valid_skill_draft(&context, &name, &words);
        let foreign = ScopeDefect::ForeignWorkspace;
        apply_scope_defect(&context, &mut skill.scope, foreign);
        let empty = ScopeDefect::EmptyProjectList;
        apply_scope_defect(&context, &mut skill.scope, empty);

        let checked = check_item_draft(&context, &ItemDraft::Skill(skill));

        let expected =
            vec![FOREIGN_WORKSPACE.to_owned(), EMPTY_SCOPE.to_owned()];
        prop_assert_eq!(checked.problems, expected);
    }
}
