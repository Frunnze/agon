use std::collections::BTreeMap;
use std::fs;

use orchestration_hub::repository_reading::RepositoryReadError;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::repository_copies::{
    CaseResult, FileTree, MAIN_BRANCH, REPOSITORY_CASES, RepositoryCopy,
    create_repository, list_main_folder,
};

const OBJECTS_FOLDER: &str = ".git/objects";
const TREE_LISTING_PROGRAM: &str = "ls-tree";
const OBJECT_FOLDER_LENGTH: usize = 2;

fn any_name() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9 ._é-]{0,8}"
}

fn any_content() -> impl Strategy<Value = Vec<u8>> {
    "[a-z ]{0,30}".prop_map(String::into_bytes)
}

fn remove_object(copy: &RepositoryCopy, path: &str) -> CaseResult<String> {
    let object = copy.git(&["rev-parse", &format!("HEAD:{path}")])?;
    let (folder, rest) = object.split_at(OBJECT_FOLDER_LENGTH);
    let object_file = copy.root.join(OBJECTS_FOLDER).join(folder).join(rest);
    fs::remove_file(object_file).map_err(to_case_error)?;
    Ok(object)
}

fn commit_with_missing_blob(
    folder: &str,
    missing_name: &str,
    missing_content: &[u8],
    healthy: &FileTree,
) -> CaseResult<(RepositoryCopy, String)> {
    let copy = create_repository()?;
    let missing_path = format!("{folder}/{missing_name}");
    let mut files = healthy.clone();
    files.insert(missing_path.clone(), missing_content.to_vec());
    files.insert(format!("{folder}/{missing_name}.kept"), b"kept".to_vec());
    copy.commit_tree(&files)?;
    let object = remove_object(&copy, &missing_path)?;
    Ok((copy, object))
}

fn is_tree_listing_failure(
    problem: &RepositoryReadError,
    object: &str,
) -> bool {
    let RepositoryReadError::GitFailed { arguments, output } = problem else {
        return false;
    };
    arguments.contains(TREE_LISTING_PROGRAM) && output.contains(object)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPOSITORY_CASES))]

    #[test]
    fn test_parse_tree_record_property_missing_blob_is_a_git_failure(
        name in any_name(),
        content in any_content(),
    ) {
        let (copy, object) = commit_with_missing_blob(
            "src",
            &name,
            &content,
            &FileTree::new(),
        )?;
        let reader = copy.open_reader()?;

        let listing = reader.list_folder(MAIN_BRANCH, "src");

        let Err(problem) = listing else {
            return Err(to_case_error(format!("{listing:?}")));
        };
        prop_assert!(
            is_tree_listing_failure(&problem, &object),
            "{problem:?}"
        );
    }

    #[test]
    fn test_parse_tree_record_property_reading_by_a_missing_blob_is_a_failure(
        name in any_name(),
        content in any_content(),
    ) {
        let (copy, object) = commit_with_missing_blob(
            "src",
            &name,
            &content,
            &FileTree::new(),
        )?;
        let reader = copy.open_reader()?;

        let missing = reader.read_file(MAIN_BRANCH, &format!("src/{name}"));
        let beside =
            reader.read_file(MAIN_BRANCH, &format!("src/{name}.kept"));

        let is_unreadable_answer = |read: &Result<_, RepositoryReadError>| {
            matches!(read, Err(RepositoryReadError::UnreadableAnswer(_)))
        };
        prop_assert!(!is_unreadable_answer(&missing), "{missing:?}");
        prop_assert!(!is_unreadable_answer(&beside), "{beside:?}");
        let Err(problem) = missing else {
            return Err(to_case_error("a missing blob was read"));
        };
        let is_git_failure =
            matches!(problem, RepositoryReadError::GitFailed { .. });
        prop_assert!(is_git_failure, "{problem:?} {object}");
    }

    #[test]
    fn test_parse_tree_record_property_healthy_folders_still_list(
        name in any_name(),
        content in any_content(),
        other_names in proptest::collection::btree_set(any_name(), 1..4),
    ) {
        let healthy: FileTree = other_names
            .iter()
            .map(|other| (format!("docs/{other}"), b"fine".to_vec()))
            .collect();
        let (copy, _object) =
            commit_with_missing_blob("src", &name, &content, &healthy)?;
        let reader = copy.open_reader()?;

        let entries = list_main_folder(&reader, "docs")?;
        let root = list_main_folder(&reader, "")?;

        let listed: Vec<String> =
            entries.into_iter().map(|entry| entry.name).collect();
        let expected: Vec<String> = other_names.into_iter().collect();
        prop_assert_eq!(listed.len(), expected.len());
        let mut sorted_listed = listed.clone();
        sorted_listed.sort();
        prop_assert_eq!(sorted_listed, expected);
        let root_names: BTreeMap<String, bool> = root
            .into_iter()
            .map(|entry| (entry.name, entry.size.is_none()))
            .collect();
        prop_assert_eq!(root_names.get("src"), Some(&true));
    }
}
