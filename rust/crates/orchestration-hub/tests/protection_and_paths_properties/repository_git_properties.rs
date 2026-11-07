use std::collections::BTreeMap;
use std::fs;

use orchestration_core::repository_files::FilePreview;
use orchestration_hub::repository_reading::RepositoryReadError;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::repository_copies::{
    MAIN_BRANCH, REPOSITORY_CASES, any_file_tree, create_repository,
    list_main_folder, read_main_file, write_file,
};

const OBJECTS_FOLDER: &str = ".git/objects";
const BRANCH_LISTING_PROGRAM: &str = "for-each-ref ";

fn any_unusual_name() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("-x".to_owned()),
        Just("--output=copy".to_owned()),
        Just("tab\tname".to_owned()),
        Just("line\nbreak".to_owned()),
        Just("colon:name".to_owned()),
        Just("^{tree}".to_owned()),
        Just("@{1}".to_owned()),
        "[a-z]{1,4} [a-z]{1,4}",
    ]
}

fn text_preview(content: &str) -> FilePreview {
    FilePreview::Text {
        text: content.to_owned(),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPOSITORY_CASES))]

    #[test]
    fn test_run_git_property_unusual_names_are_only_paths(
        name in any_unusual_name(),
        content in "[a-z]{0,20}",
    ) {
        let copy = create_repository()?;
        let path = format!("src/{name}");
        let content_bytes = content.clone().into_bytes();
        let files = BTreeMap::from([(path.clone(), content_bytes)]);
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;

        let entries = list_main_folder(&reader, "src")?;
        let read = reader.read_file(MAIN_BRANCH, &path);

        let names: Vec<&str> =
            entries.iter().map(|entry| entry.name.as_str()).collect();
        if name.chars().any(char::is_control) {
            prop_assert!(names.is_empty(), "{:?}", names);
            prop_assert!(matches!(read, Err(RepositoryReadError::Path(_))));
        } else {
            prop_assert_eq!(names, vec![name.as_str()]);
            let file = read.map_err(to_case_error)?;
            prop_assert_eq!(file.preview, text_preview(&content));
        }
    }

    #[test]
    fn test_run_git_property_reads_commits_not_the_working_folder(
        files in any_file_tree(),
        changed in "[A-Z]{1,20}",
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        for path in files.keys() {
            write_file(&copy.root, path, changed.as_bytes())?;
        }
        let reader = copy.open_reader()?;

        for (path, content) in &files {
            let file = read_main_file(&reader, path)?;
            let text = String::from_utf8_lossy(content).into_owned();
            prop_assert_eq!(file.preview, text_preview(&text));
        }
    }

    #[test]
    fn test_run_git_with_property_failures_name_the_arguments(
        files in any_file_tree(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&files)?;
        let (folder, rest) = commit.split_at(2);
        let object = copy.root.join(OBJECTS_FOLDER).join(folder).join(rest);
        fs::remove_file(object).map_err(to_case_error)?;
        let reader = copy.open_reader()?;

        let listing = reader.list_branches();

        let Err(RepositoryReadError::GitFailed { arguments, output }) = listing
        else {
            return Err(to_case_error(format!("{listing:?}")));
        };
        let is_branch_listing = arguments.starts_with(BRANCH_LISTING_PROGRAM);
        prop_assert!(is_branch_listing, "{}", arguments);
        prop_assert!(output.contains(&commit), "{}", output);
        prop_assert_eq!(output.trim(), output.as_str());
    }

    #[test]
    fn test_run_git_with_property_listing_survives_a_missing_working_folder(
        files in any_file_tree(),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        for path in files.keys() {
            fs::remove_file(copy.root.join(path)).map_err(to_case_error)?;
        }
        let reader = copy.open_reader()?;

        let branches = reader.list_branches().map_err(to_case_error)?;
        let entries = list_main_folder(&reader, "")?;

        prop_assert_eq!(branches.branches, vec![MAIN_BRANCH.to_owned()]);
        prop_assert!(!entries.is_empty());
    }
}
