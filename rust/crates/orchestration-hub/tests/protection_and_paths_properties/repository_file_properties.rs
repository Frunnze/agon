use std::fs;

use orchestration_core::repository_files::{FilePreview, RepositoryEntryKind};
use orchestration_hub::repository_reading::{
    RepositoryReadError, RepositoryReader,
};
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::repository_copies::{
    MAIN_BRANCH, REPOSITORY_CASES, any_file_tree, create_empty_folder,
    create_repository, list_direct_children, list_main_folder, read_main_file,
};

const SPELLING_NOISE: [&str; 3] = ["./", "/", ""];

fn any_folder_choice() -> impl Strategy<Value = &'static str> {
    prop_oneof![Just(""), Just("src"), Just("docs"), Just("Assets")]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPOSITORY_CASES))]

    #[test]
    fn test_repository_reader_open_property_needs_a_git_folder(
        folders in proptest::collection::vec("[a-z]{1,6}", 0..3),
        is_git_file in any::<bool>(),
    ) {
        let temporary = create_empty_folder()?;
        let mut place = temporary.path().to_path_buf();
        for folder in &folders {
            place.push(folder);
        }
        fs::create_dir_all(&place).map_err(to_case_error)?;
        if is_git_file {
            fs::write(place.join(".git"), "gitdir: elsewhere")
                .map_err(to_case_error)?;
        }

        let opened = RepositoryReader::open(&place);

        prop_assert!(matches!(opened, Err(RepositoryReadError::NoCopy)));
    }

    #[test]
    fn test_repository_reader_open_property_reads_any_real_copy(
        files in any_file_tree(),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;

        let reader = copy.open_reader()?;
        let root_entries =
            reader.list_folder(MAIN_BRANCH, "").map_err(to_case_error)?;

        let expected_count = list_direct_children(&files, "").len();
        prop_assert_eq!(root_entries.len(), expected_count);
    }

    #[test]
    fn test_repository_reader_open_property_empty_copy_has_no_branches(
        extra_folders in proptest::collection::vec("[a-z]{1,6}", 0..3),
    ) {
        let copy = create_repository()?;
        for folder in &extra_folders {
            fs::create_dir_all(copy.root.join(folder)).map_err(to_case_error)?;
        }

        let reader = copy.open_reader()?;
        let branches = reader.list_branches().map_err(to_case_error)?;
        let listing = reader.list_folder(MAIN_BRANCH, "");

        prop_assert!(branches.branches.is_empty());
        prop_assert!(branches.task_branches.is_empty());
        let is_unknown = matches!(
            listing,
            Err(RepositoryReadError::UnknownBranch(_)),
        );
        prop_assert!(is_unknown);
    }

    #[test]
    fn test_list_folder_property_lists_exactly_the_direct_children(
        files in any_file_tree(),
        folder in any_folder_choice(),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;
        let expected = list_direct_children(&files, folder);
        prop_assume!(folder.is_empty() || !expected.is_empty());

        let entries =
            reader.list_folder(MAIN_BRANCH, folder).map_err(to_case_error)?;

        let mut listed = std::collections::BTreeMap::new();
        for entry in &entries {
            let is_folder = entry.kind == RepositoryEntryKind::Folder;
            listed.insert(entry.name.clone(), is_folder);
        }
        prop_assert_eq!(entries.len(), expected.len());
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_folder_property_folders_first_then_names_ignoring_case(
        files in any_file_tree(),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;

        let entries = list_main_folder(&reader, "")?;

        for pair in entries.windows(2) {
            let first_is_file = pair[0].kind != RepositoryEntryKind::Folder;
            let second_is_file = pair[1].kind != RepositoryEntryKind::Folder;
            let first_key = (first_is_file, pair[0].name.to_lowercase());
            let second_key = (second_is_file, pair[1].name.to_lowercase());
            prop_assert!(first_key <= second_key, "{:?}", entries);
        }
    }

    #[test]
    fn test_list_folder_property_spelling_of_the_folder_does_not_matter(
        files in any_file_tree(),
        folder in prop_oneof![Just("src"), Just("docs"), Just("Assets")],
        before in prop::sample::select(SPELLING_NOISE.to_vec()),
        after in prop::sample::select(SPELLING_NOISE.to_vec()),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;
        let spelled = format!("{before}{folder}/{after}");
        prop_assume!(!spelled.starts_with('/'));

        let plain = reader.list_folder(MAIN_BRANCH, folder);
        let respelled = reader.list_folder(MAIN_BRANCH, &spelled);

        prop_assert_eq!(format!("{plain:?}"), format!("{respelled:?}"));
    }

    #[test]
    fn test_read_tree_property_a_file_is_not_a_folder(
        files in any_file_tree(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;
        let paths: Vec<&String> = files.keys().collect();
        let file_path = chosen.get(&paths);

        let listing = reader.list_folder(MAIN_BRANCH, file_path);
        let inside = reader.read_file(MAIN_BRANCH, &format!("{file_path}/x"));

        let is_not_folder =
            matches!(listing, Err(RepositoryReadError::NotAFolder(_)));
        prop_assert!(is_not_folder, "{:?}", listing);
        let is_not_found =
            matches!(inside, Err(RepositoryReadError::NotFound(_)));
        prop_assert!(is_not_found, "{:?}", inside);
    }

    #[test]
    fn test_read_file_property_text_comes_back_whole(
        files in any_file_tree(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;
        let paths: Vec<&String> = files.keys().collect();
        let file_path = chosen.get(&paths);
        let content = &files[*file_path];

        let file = read_main_file(&reader, file_path)?;

        prop_assert_eq!(&file.path, *file_path);
        prop_assert_eq!(file.size, content.len() as u64);
        let text = String::from_utf8_lossy(content).into_owned();
        prop_assert_eq!(file.preview, FilePreview::Text { text });
    }

    #[test]
    fn test_read_file_property_folders_and_missing_files_are_refused(
        files in any_file_tree(),
        missing in "[a-z]{1,6}\\.missing",
    ) {
        let copy = create_repository()?;
        copy.commit_tree(&files)?;
        let reader = copy.open_reader()?;
        let folders = list_direct_children(&files, "");

        let missing_file = reader.read_file(MAIN_BRANCH, &missing);

        let is_missing =
            matches!(missing_file, Err(RepositoryReadError::NotFound(_)));
        prop_assert!(is_missing);
        for (name, is_folder) in folders {
            let read = reader.read_file(MAIN_BRANCH, &name);
            prop_assert_eq!(
                matches!(read, Err(RepositoryReadError::NotAFile(_))),
                is_folder,
            );
        }
    }

    #[test]
    fn test_read_file_property_links_are_never_followed(
        target in prop_oneof![
            Just("../../outside".to_owned()),
            Just("src".to_owned()),
            "[a-z]{1,8}",
        ],
        name in "[a-z]{1,6}-link",
    ) {
        let copy = create_repository()?;
        copy.add_link(&name, &target)?;
        copy.commit_tree(&std::collections::BTreeMap::new())?;
        let reader = copy.open_reader()?;

        let file = read_main_file(&reader, &name)?;
        let through_link = reader.list_folder(MAIN_BRANCH, &name);

        prop_assert_eq!(file.preview, FilePreview::Link);
        prop_assert_eq!(file.size, target.len() as u64);
        let is_not_folder =
            matches!(through_link, Err(RepositoryReadError::NotAFolder(_)));
        prop_assert!(is_not_folder);
    }
}
