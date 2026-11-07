use std::collections::{BTreeMap, BTreeSet};

use orchestration_core::repository_files::FilePreview;
use orchestration_hub::repository_reading::RepositoryReadError;
use proptest::prelude::*;

use crate::repository_copies::{
    MAIN_BRANCH, REPOSITORY_CASES, any_file_tree, create_repository,
    list_branches, list_direct_children, list_main_folder, read_main_file,
};

fn any_flat_names() -> impl Strategy<Value = BTreeSet<String>> {
    proptest::collection::btree_set("[a-z][a-z0-9-]{0,6}", 1..5)
        .prop_filter("the checked out branch is listed apart", |names| {
            !names.contains(MAIN_BRANCH)
        })
}

fn any_head_like_name() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("HEADS".to_owned()),
        Just("head".to_owned()),
        Just("x-HEAD".to_owned()),
        Just("origin".to_owned()),
        Just("origin-copy".to_owned()),
        Just("task/HEAD".to_owned()),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPOSITORY_CASES))]

    #[test]
    fn test_list_branches_property_same_commit_branches_come_by_name(
        names in any_flat_names(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&BTreeMap::new())?;
        for name in &names {
            copy.git(&["branch", name, &commit])?;
        }

        let branches = list_branches(&copy.open_reader()?)?;

        let mut sorted = branches.branches.clone();
        sorted.sort();
        prop_assert_eq!(branches.branches, sorted);
    }

    #[test]
    fn test_list_branches_property_listing_twice_gives_the_same(
        names in any_flat_names(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&BTreeMap::new())?;
        for name in &names {
            copy.point_remote(name, &commit)?;
        }
        let reader = copy.open_reader()?;

        let first_listing = list_branches(&reader)?;
        let second_listing = list_branches(&reader)?;

        prop_assert_eq!(first_listing, second_listing);
    }

    #[test]
    fn test_list_references_property_remote_only_branches_are_listed(
        names in any_flat_names(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&BTreeMap::new())?;
        for name in &names {
            copy.point_remote(name, &commit)?;
        }

        let branches = list_branches(&copy.open_reader()?)?;

        for name in &names {
            prop_assert!(branches.branches.contains(name), "{}", name);
        }
    }

    #[test]
    fn test_list_references_property_tags_and_other_remotes_are_not_branches(
        names in any_flat_names(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&BTreeMap::new())?;
        for name in &names {
            copy.git(&["tag", name, &commit])?;
            let other_remote = format!("refs/remotes/upstream/{name}");
            copy.git(&["update-ref", &other_remote, &commit])?;
        }
        let reader = copy.open_reader()?;

        let branches = list_branches(&reader)?;

        prop_assert_eq!(branches.branches, vec![MAIN_BRANCH.to_owned()]);
        for name in &names {
            let read = reader.read_file(name, "missing.txt");
            let is_unknown =
                matches!(read, Err(RepositoryReadError::UnknownBranch(_)));
            prop_assert!(is_unknown, "{:?}", read);
        }
    }

    #[test]
    fn test_name_branch_property_remote_names_lose_only_the_remote(
        name in any_head_like_name(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&BTreeMap::new())?;
        copy.point_remote(&name, &commit)?;

        let branches = list_branches(&copy.open_reader()?)?;

        let listed: Vec<&String> = branches
            .branches
            .iter()
            .chain(&branches.task_branches)
            .collect();
        prop_assert!(listed.contains(&&name), "{:?}", listed);
    }

    #[test]
    fn test_name_branch_property_local_names_are_kept_whole(
        name in any_head_like_name(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&BTreeMap::new())?;
        copy.git(&["branch", &name, &commit])?;

        let branches = list_branches(&copy.open_reader()?)?;

        let listed: Vec<&String> = branches
            .branches
            .iter()
            .chain(&branches.task_branches)
            .collect();
        prop_assert!(listed.contains(&&name), "{:?}", listed);
    }

    #[test]
    fn test_read_tree_property_missing_folders_are_not_folders(
        files in any_file_tree(),
        missing in "[a-z]{1,6}-missing",
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;

        let listing = reader.list_folder(MAIN_BRANCH, &missing);

        let is_not_folder =
            matches!(listing, Err(RepositoryReadError::NotAFolder(_)));
        prop_assert!(is_not_folder, "{:?}", listing);
    }

    #[test]
    fn test_read_tree_property_deep_folders_list_their_children(
        folders in proptest::collection::vec("[a-z]{1,5}", 1..4),
        names in proptest::collection::btree_set("[a-z]{1,6}\\.txt", 1..4),
    ) {
        let copy = create_repository()?;
        let folder = folders.join("/");
        let mut files = BTreeMap::new();
        for name in &names {
            let path = format!("{folder}/{name}");
            files.insert(path, name.clone().into_bytes());
        }
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;

        let entries = list_main_folder(&reader, &folder)?;

        let listed: BTreeSet<String> =
            entries.iter().map(|entry| entry.name.clone()).collect();
        prop_assert_eq!(&listed, &names);
        let expected = list_direct_children(&files, &folder);
        prop_assert_eq!(entries.len(), expected.len());
    }

    #[test]
    fn test_run_git_property_binary_blobs_come_back_as_binary(
        content in proptest::collection::vec(any::<u8>(), 1..200),
        name in "[a-z]{1,6}\\.bin",
    ) {
        prop_assume!(std::str::from_utf8(&content).is_err());
        let copy = create_repository()?;
        let files = BTreeMap::from([(name.clone(), content.clone())]);
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;

        let file = read_main_file(&reader, &name)?;

        prop_assert_eq!(file.size, content.len() as u64);
        let is_not_text = !matches!(file.preview, FilePreview::Text { .. });
        prop_assert!(is_not_text, "{:?}", file.preview);
    }

    #[test]
    fn test_run_git_with_property_each_reader_reads_its_own_copy(
        first_content in "[a-z]{1,20}",
        second_content in "[A-Z]{1,20}",
        name in "[a-z]{1,6}\\.txt",
    ) {
        let first_copy = create_repository()?;
        let second_copy = create_repository()?;
        let first_bytes = first_content.clone().into_bytes();
        let second_bytes = second_content.clone().into_bytes();
        let first_files = BTreeMap::from([(name.clone(), first_bytes)]);
        let second_files = BTreeMap::from([(name.clone(), second_bytes)]);
        first_copy.commit_tree(&first_files)?;
        second_copy.commit_tree(&second_files)?;

        let first_file = read_main_file(&first_copy.open_reader()?, &name)?;
        let second_file = read_main_file(&second_copy.open_reader()?, &name)?;

        let first_text = FilePreview::Text { text: first_content };
        let second_text = FilePreview::Text { text: second_content };
        prop_assert_eq!(first_file.preview, first_text);
        prop_assert_eq!(second_file.preview, second_text);
    }
}
