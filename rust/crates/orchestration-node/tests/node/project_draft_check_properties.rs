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
use crate::support::git_folders::create_git_folder;
use crate::support::git_origin::run_git;
use crate::support::test_device::fail;

const PROJECT_CASES: u32 = 8;
const PROJECT_NAME_PATTERN: &str = "[a-z][a-z0-9]{2,8}";
const BRANCH_PATTERN: &str = "[a-z][a-z0-9-]{0,8}[a-z0-9]";
const INNER_FOLDER_NAME: &str = "inner";
const NO_REPOSITORY: &str =
    "Repos: none found. Ask for changes and say where the code is.";
const FOREIGN_FOLDER_NAME: &str = "app-on-another-computer";
const REPOSITORY_FIX: &str = "Ask for changes and give a GitHub address or a \
                              git folder on this computer.";

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
        approval_policy: None,
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

fn describe_repository_problem(problem: &str) -> String {
    format!("Repos: {problem}. {REPOSITORY_FIX}")
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
    let Ok(git_folder) = create_git_folder(parent.path(), "main") else {
        panic!("the git folder is made");
    };
    let inner_folder = git_folder.join(INNER_FOLDER_NAME);
    let Ok(()) = fs::create_dir_all(&inner_folder) else {
        panic!("the inner folder is made");
    };
    let inner_path = inner_folder.display().to_string();
    let foreign_folder = parent.path().join(FOREIGN_FOLDER_NAME);
    let foreign_path = foreign_folder.display().to_string();
    let foreign_address = format!("local:{FOREIGN_DEVICE_ID}:{foreign_path}");
    let drafted = project_draft(
        "billing",
        vec![
            repository(&missing_path, "main"),
            repository(&inner_path, "main"),
            repository(&foreign_address, "main"),
            repository("ftp://github.com/acme/app", "main"),
            repository("https://github.com/acme/app", " "),
        ],
    );

    let (repositories, problems) = check_project(&empty_context(), &drafted);

    let missing_folder = format!(
        "the folder {missing_path} does not exist or this app cannot open it"
    );
    let inner_problem =
        format!("the folder {inner_path} is not a git repository");
    let foreign_problem = format!(
        "the folder {foreign_path} is on another computer, so add it there"
    );
    let expected = vec![
        describe_repository_problem(&missing_folder),
        describe_repository_problem(&inner_problem),
        describe_repository_problem(&foreign_problem),
        describe_repository_problem(
            "only https and git@ addresses are supported, not ftp",
        ),
    ];
    assert_eq!(problems, expected);
    let github_on_main = repository("github.com/acme/app", "main");
    assert_eq!(repositories, vec![github_on_main]);
}

#[test]
fn a_detached_folder_has_no_branch_checked_out() {
    let parent = temporary_folder();
    let Ok(folder) = create_git_folder(parent.path(), "main") else {
        panic!("the git folder is made");
    };
    let Ok(_) = run_git(&folder, &["checkout", "--quiet", "--detach"]) else {
        panic!("the head is detached");
    };
    let path = folder.display().to_string();
    let drafted = project_draft("billing", vec![repository(&path, "main")]);

    let (repositories, problems) = check_project(&empty_context(), &drafted);

    let detached = format!("the folder {path} has no branch checked out");
    assert_eq!(problems, vec![describe_repository_problem(&detached)]);
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
fn test_check_item_draft_property_a_missing_branch_defaults_to_main() {
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));

    let outcome = runner.run(&PROJECT_NAME_PATTERN, |name| {
        let parent = TempDir::new().map_err(fail)?;
        let folder = create_git_folder(parent.path(), "main").map_err(fail)?;
        let address = this_device_address(&folder.display().to_string());
        let drafted = project_draft(&name, vec![repository(&address, "")]);

        let (repositories, problems) =
            check_project(&empty_context(), &drafted);

        prop_assert!(problems.is_empty(), "{:?}", problems);
        prop_assert_eq!(repositories, vec![repository(&address, "main")]);
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

        let taken_sentence = format!(
            "Name: a project named {name} already exists. Ask for changes \
             and give another name."
        );
        prop_assert_eq!(taken_problems, vec![taken_sentence]);
        let invalid_sentence = "Name: a name can only use lowercase letters, \
                                digits and dashes, not 'B'. Ask for changes \
                                and give another name.";
        prop_assert_eq!(invalid_problems, vec![invalid_sentence.to_owned()]);
    }
}
