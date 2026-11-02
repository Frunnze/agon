use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    DraftingContext, ItemDraft, ProjectDraft, RepositoryDraft,
    add_chosen_folders,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::drafting_samples::{
    context_strategy, valid_rule_draft, valid_skill_draft, valid_work_draft,
};

const FOLDER_CASES: u32 = 32;
const MOST_REPOSITORIES: usize = 4;
const ADDRESS_PATTERN: &str = "[a-z0-9:/.-]{0,24}";
const BRANCH_PATTERN: &str = "[a-z0-9-]{0,8}";
const NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";

fn build_repository(
    (address, default_branch): (String, String),
) -> RepositoryDraft {
    RepositoryDraft {
        address,
        default_branch,
    }
}

fn repository_strategy() -> impl Strategy<Value = RepositoryDraft> {
    (ADDRESS_PATTERN, BRANCH_PATTERN).prop_map(build_repository)
}

fn project_draft(name: &str, repositories: Vec<RepositoryDraft>) -> ItemDraft {
    ItemDraft::Project(ProjectDraft {
        name: name.to_owned(),
        repositories,
        agent_access: AgentAccess::ReadOnly,
    })
}

fn build_other_draft(
    (context, words, choice): (DraftingContext, String, u8),
) -> ItemDraft {
    match choice {
        0 => ItemDraft::Task(valid_work_draft(&context, &words, "")),
        1 => ItemDraft::Job(valid_work_draft(&context, &words, "")),
        2 => ItemDraft::Skill(valid_skill_draft(&context, &words, "")),
        _ => ItemDraft::Rule(valid_rule_draft(&context, &words)),
    }
}

fn other_draft_strategy() -> impl Strategy<Value = ItemDraft> {
    let choices = (context_strategy(), NAME_PATTERN, 0..4_u8);
    choices.prop_map(build_other_draft)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FOLDER_CASES))]

    #[test]
    fn test_add_chosen_folders_property_folders_follow_the_agent_repos(
        name in NAME_PATTERN,
        answered in vec(repository_strategy(), 0..MOST_REPOSITORIES),
        chosen in vec(repository_strategy(), 0..MOST_REPOSITORIES),
    ) {
        let drafted = project_draft(&name, answered.clone());

        let added = add_chosen_folders(drafted, &chosen);

        let mut expected_repositories = answered;
        expected_repositories.extend(chosen);
        prop_assert_eq!(added, project_draft(&name, expected_repositories));
    }

    #[test]
    fn test_add_chosen_folders_property_no_folders_keep_any_draft(
        drafted in prop_oneof![
            other_draft_strategy(),
            (NAME_PATTERN, vec(repository_strategy(), 0..MOST_REPOSITORIES))
                .prop_map(|(name, answered)| project_draft(&name, answered)),
        ],
    ) {
        let added = add_chosen_folders(drafted.clone(), &[]);

        prop_assert_eq!(added, drafted);
    }
}
