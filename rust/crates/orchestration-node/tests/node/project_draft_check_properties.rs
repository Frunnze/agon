use std::fs;

use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    DraftingContext, ItemDraft, ProjectDraft, RepositoryDraft,
    add_chosen_folders, check_item_draft,
};
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use tempfile::TempDir;

use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, THIS_DEVICE_ID, context_strategy, empty_context,
    padded, sample_project,
};
use crate::support::git_folders::{
    GIT_FOLDER_NAME, HEAD_FILE_NAME, create_git_folder,
};
use crate::support::test_device::fail;

const PROJECT_CASES: u32 = 8;
const PROJECT_NAME_PATTERN: &str = "[a-z][a-z0-9]{2,8}";
const BRANCH_PATTERN: &str = "[a-z][a-z0-9-]{0,8}[a-z0-9]";
const DETACHED_HEAD: &str = "4b825dc642cb6eb9a060e54bf8d69288fbee4904";
const NO_REPOSITORY: &str =
    "The agent found no repo. Ask for changes and say where the code is.";

fn repository(address: &str, default_branch: &str) -> RepositoryDraft {
    RepositoryDraft {
        address: address.to_owned(),
        default_branch: default_branch.to_owned(),
    }
}

fn project_draft(name: &str, repositories: Vec<RepositoryDraft>) -> ItemDraft {
    ItemDraft::Project(ProjectDraft {
        name: name.to_owned(),
        repositories,
        agent_access: AgentAccess::PushAfterApproval,
    })
}

fn check_project(
    context: &DraftingContext,
    drafted: &ItemDraft,
) -> (Vec<RepositoryDraft>, Vec<String>) {
    let checked = check_item_draft(context, drafted);
    let ItemDraft::Project(project) = checked.draft else {
        return (Vec::new(), vec!["the draft is no project".to_owned()]);
    };
    (project.repositories, checked.problems)
}

fn this_device_address(path: &str) -> String {
    format!("local:{THIS_DEVICE_ID}:{path}")
}

fn temporary_folder() -> TempDir {
    match TempDir::new() {
        Ok(folder) => folder,
        Err(error) => panic!("the temporary folder is made: {error}"),
    }
}

#[test]
fn folder_problems_are_written_as_sentences() {
    let parent = temporary_folder();
    let parent_path = parent.path().display().to_string();
    let missing_path = format!("{parent_path}/missing");
    let foreign_address = format!("local:{FOREIGN_DEVICE_ID}:/Users/someone/app");
    let drafted = project_draft(
        "billing",
        vec![
            repository(&missing_path, "main"),
            repository(&parent_path, "main"),
            repository(&foreign_address, "main"),
            repository("ftp://github.com/acme/app", "main"),
            repository("https://github.com/acme/app", " "),
        ],
    );

    let (repositories, problems) = check_project(&empty_context(), &drafted);

    let expected = vec![
        format!(
            "The folder {missing_path} does not exist or this app cannot \
             open it."
        ),
        format!("The folder {parent_path} is not a git repository."),
        "The folder /Users/someone/app is on another computer, so add it there."
            .to_owned(),
        "Only https and git@ addresses are supported, not ftp.".to_owned(),
        "The agent gave no branch for github.com/acme/app.".to_owned(),
    ];
    assert_eq!(problems, expected);
    assert!(repositories.is_empty(), "{repositories:?}");
}

#[test]
fn a_detached_folder_has_no_branch_checked_out() {
    let parent = temporary_folder();
    let Ok(folder) = create_git_folder(parent.path(), "main") else {
        panic!("the git folder is made");
    };
    let head_path = folder.join(GIT_FOLDER_NAME).join(HEAD_FILE_NAME);
    let Ok(()) = fs::write(head_path, DETACHED_HEAD) else {
        panic!("the head is detached");
    };
    let path = folder.display().to_string();
    let drafted = project_draft("billing", vec![repository(&path, "main")]);

    let (repositories, problems) = check_project(&empty_context(), &drafted);

    let expected = format!("The folder {path} has no branch checked out.");
    assert_eq!(problems, vec![expected]);
    assert!(repositories.is_empty(), "{repositories:?}");
}

#[test]
fn test_check_item_draft_property_a_git_folder_becomes_a_local_address() {
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let strategy = (PROJECT_NAME_PATTERN, BRANCH_PATTERN);

    let outcome = runner.run(&strategy, |(name, branch)| {
        let parent = TempDir::new().map_err(fail)?;
        let folder =
            create_git_folder(parent.path(), &branch).map_err(fail)?;
        let path = folder.display().to_string();
        let drafted = project_draft(
            &padded(&name),
            vec![
                repository(&padded(&path), "ignored"),
                repository(&this_device_address(&path), &padded(&branch)),
                repository("git@github.com:acme/app.git", &padded("main")),
                repository("https://github.com/acme/app", "develop"),
            ],
        );

        let checked = check_item_draft(&empty_context(), &drafted);

        let expected = project_draft(
            &name,
            vec![
                repository(&this_device_address(&path), &branch),
                repository("github.com/acme/app", "main"),
            ],
        );
        prop_assert_eq!(checked.draft, expected);
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_item_draft_property_a_local_address_needs_a_branch() {
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));

    let outcome = runner.run(&PROJECT_NAME_PATTERN, |name| {
        let parent = TempDir::new().map_err(fail)?;
        let folder = create_git_folder(parent.path(), "main").map_err(fail)?;
        let address = this_device_address(&folder.display().to_string());
        let drafted = project_draft(&name, vec![repository(&address, "")]);

        let (repositories, problems) =
            check_project(&empty_context(), &drafted);

        let expected = format!("The agent gave no branch for {address}.");
        prop_assert_eq!(problems, vec![expected]);
        prop_assert!(repositories.is_empty());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROJECT_CASES))]

    #[test]
    fn test_add_chosen_folders_property_a_chosen_folder_is_checked_once(
        name in PROJECT_NAME_PATTERN,
        branch in BRANCH_PATTERN,
        agent_named_it in any::<bool>(),
    ) {
        let parent = TempDir::new().map_err(fail)?;
        let folder =
            create_git_folder(parent.path(), &branch).map_err(fail)?;
        let path = folder.display().to_string();
        let chosen = repository(&this_device_address(&path), &branch);
        let github = repository("github.com/acme/app", "main");
        let mut answered = vec![github.clone()];
        if agent_named_it {
            answered.insert(0, repository(&path, "ignored"));
        }

        let drafted = add_chosen_folders(
            project_draft(&name, answered),
            std::slice::from_ref(&chosen),
        );
        let (repositories, problems) =
            check_project(&empty_context(), &drafted);

        let expected = if agent_named_it {
            vec![chosen, github]
        } else {
            vec![github, chosen]
        };
        prop_assert_eq!(repositories, expected);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_check_item_draft_property_a_project_without_repos_is_refused(
        context in context_strategy(),
        name in PROJECT_NAME_PATTERN,
    ) {
        let drafted = project_draft(&name, Vec::new());

        let (_, problems) = check_project(&context, &drafted);

        prop_assert_eq!(problems, vec![NO_REPOSITORY.to_owned()]);
    }

    #[test]
    fn test_check_item_draft_property_project_name_problems_are_sentences(
        context in context_strategy(),
        name in PROJECT_NAME_PATTERN,
    ) {
        let mut context = context;
        context.projects.push(sample_project(9, &name, "github.com/a/b"));
        let github = repository("github.com/acme/app", "main");
        let taken = project_draft(&name, vec![github.clone()]);
        let invalid = project_draft("Billing", vec![github]);

        let (_, taken_problems) = check_project(&context, &taken);
        let (_, invalid_problems) = check_project(&context, &invalid);

        let taken_sentence = format!("A project named {name} already exists.");
        prop_assert_eq!(taken_problems, vec![taken_sentence]);
        let invalid_sentence = "A name can only use lowercase letters, \
                                digits and dashes, not 'B'.";
        prop_assert_eq!(invalid_problems, vec![invalid_sentence.to_owned()]);
    }
}
