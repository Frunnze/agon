use std::collections::{BTreeMap, BTreeSet};
use std::fs;

use orchestration_core::repository_files::FilePreview;
use orchestration_hub::branch_names::TASK_BRANCH_PREFIX;
use orchestration_hub::repository_reading::RepositoryReadError;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::repository_copies::{
    FileTree, MAIN_BRANCH, REPOSITORY_CASES, create_repository, list_branches,
};

const MARKER_FILE: &str = "marker.txt";
const PACKED_REFERENCES_FILE: &str = ".git/packed-refs";
const UNREADABLE_BRANCH_BYTES: [u8; 3] = [b'x', 0xff, b'y'];

fn any_branch_names() -> impl Strategy<Value = BTreeSet<String>> {
    let plain = "[a-z][a-z0-9-]{0,6}";
    let task = "[a-z][a-z0-9-]{0,6}".prop_map(|name| format!("task/{name}"));
    let accented = "[a-zé]{1,5}";
    let name = prop_oneof![plain.boxed(), task.boxed(), accented.boxed()];
    proptest::collection::btree_set(name, 0..5).prop_filter(
        "a branch name is never a branch folder nor the checked out one",
        |names| !names.contains("task") && !names.contains(MAIN_BRANCH),
    )
}

fn marker_tree(marker: &str) -> FileTree {
    BTreeMap::from([(MARKER_FILE.to_owned(), marker.as_bytes().to_vec())])
}

fn read_marker(
    reader: &orchestration_hub::repository_reading::RepositoryReader,
    branch: &str,
) -> Result<FilePreview, TestCaseError> {
    let file = reader
        .read_file(branch, MARKER_FILE)
        .map_err(to_case_error)?;
    Ok(file.preview)
}

fn text_preview(text: &str) -> FilePreview {
    FilePreview::Text {
        text: text.to_owned(),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPOSITORY_CASES))]

    #[test]
    fn test_list_branches_property_lists_every_branch_once_in_its_group(
        local in any_branch_names(),
        remote in any_branch_names(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&marker_tree("start"))?;
        for name in &local {
            copy.git(&["branch", "--force", name, &commit])?;
        }
        for name in &remote {
            copy.point_remote(name, &commit)?;
        }

        let branches = list_branches(&copy.open_reader()?)?;

        let mut expected: BTreeSet<String> =
            local.union(&remote).cloned().collect();
        expected.insert(MAIN_BRANCH.to_owned());
        let mut listed = BTreeSet::new();
        for name in branches.branches.iter().chain(&branches.task_branches) {
            prop_assert!(listed.insert(name.clone()), "{} twice", name);
        }
        prop_assert_eq!(listed, expected);
        let is_task = |name: &String| name.starts_with(TASK_BRANCH_PREFIX);
        prop_assert!(branches.task_branches.iter().all(is_task));
        prop_assert!(!branches.branches.iter().any(is_task));
    }

    #[test]
    fn test_name_branch_property_remote_head_is_not_a_branch(
        remote in any_branch_names(),
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&marker_tree("start"))?;
        copy.point_remote(MAIN_BRANCH, &commit)?;
        for name in &remote {
            copy.point_remote(name, &commit)?;
        }
        copy.point_remote_head(MAIN_BRANCH)?;
        let reader = copy.open_reader()?;

        let branches = reader.list_branches().map_err(to_case_error)?;
        let head_file = reader.read_file("HEAD", MARKER_FILE);

        prop_assert!(!branches.branches.iter().any(|name| name == "HEAD"));
        let is_unknown =
            matches!(head_file, Err(RepositoryReadError::UnknownBranch(_)));
        prop_assert!(is_unknown, "{:?}", head_file);
    }

    #[test]
    fn test_list_references_property_listed_branches_can_be_read(
        local in any_branch_names(),
        remote in any_branch_names(),
        marker in "[a-z]{1,10}",
    ) {
        let copy = create_repository()?;
        let commit = copy.commit_tree(&marker_tree(&marker))?;
        for name in &local {
            copy.git(&["branch", "--force", name, &commit])?;
        }
        for name in &remote {
            copy.point_remote(name, &commit)?;
        }
        let reader = copy.open_reader()?;

        let branches = reader.list_branches().map_err(to_case_error)?;

        for name in branches.branches.iter().chain(&branches.task_branches) {
            let preview = read_marker(&reader, name)?;
            prop_assert_eq!(preview, text_preview(&marker));
        }
    }

    #[test]
    fn test_find_branch_reference_property_task_branches_prefer_this_runner(
        name in "[a-z][a-z0-9-]{0,6}",
        local_marker in "[a-z]{1,8}",
        remote_marker in "[A-Z]{1,8}",
    ) {
        prop_assume!(name != MAIN_BRANCH);
        let copy = create_repository()?;
        let task_branch = format!("{TASK_BRANCH_PREFIX}{name}");
        let remote_commit = copy.commit_tree(&marker_tree(&remote_marker))?;
        let local_commit = copy.commit_tree(&marker_tree(&local_marker))?;
        copy.git(&["branch", &task_branch, &local_commit])?;
        copy.point_remote(&task_branch, &remote_commit)?;
        let reader = copy.open_reader()?;

        let preview = read_marker(&reader, &task_branch)?;

        prop_assert_eq!(preview, text_preview(&local_marker));
    }

    #[test]
    fn test_find_branch_reference_property_other_branches_prefer_the_remote(
        name in "[a-z][a-z0-9-]{0,6}",
        local_marker in "[a-z]{1,8}",
        remote_marker in "[A-Z]{1,8}",
    ) {
        prop_assume!(name != MAIN_BRANCH);
        let copy = create_repository()?;
        let remote_commit = copy.commit_tree(&marker_tree(&remote_marker))?;
        let local_commit = copy.commit_tree(&marker_tree(&local_marker))?;
        copy.git(&["branch", "--force", &name, &local_commit])?;
        copy.point_remote(&name, &remote_commit)?;
        let reader = copy.open_reader()?;

        let preview = read_marker(&reader, &name)?;

        prop_assert_eq!(preview, text_preview(&remote_marker));
    }

    #[test]
    fn test_find_branch_reference_property_unlisted_names_are_unknown(
        name in "[a-z][a-z0-9-]{0,6}",
        spelling in prop_oneof![
            Just("{name}^"), Just("{name}~1"), Just("refs/heads/{name}"),
            Just("{name}:"), Just("origin/{name}"), Just("-{name}"),
        ],
    ) {
        prop_assume!(name != MAIN_BRANCH);
        let copy = create_repository()?;
        let commit = copy.commit_tree(&marker_tree("start"))?;
        copy.git(&["branch", "--force", &name, &commit])?;
        copy.point_remote(&name, &commit)?;
        let reader = copy.open_reader()?;
        let spelled = spelling.replace("{name}", &name);

        let read = reader.read_file(&spelled, MARKER_FILE);

        let is_unknown =
            matches!(read, Err(RepositoryReadError::UnknownBranch(_)));
        prop_assert!(is_unknown, "{:?}", read);
    }

    #[test]
    fn test_list_references_property_unicode_branch_names_survive(
        names in proptest::collection::btree_set("[a-zé中ü]{1,6}", 1..4),
    ) {
        prop_assume!(!names.contains(MAIN_BRANCH));
        let copy = create_repository()?;
        let commit = copy.commit_tree(&marker_tree("start"))?;
        for name in &names {
            copy.git(&["branch", "--force", name, &commit])?;
        }

        let branches = list_branches(&copy.open_reader()?)?;

        for name in &names {
            prop_assert!(branches.branches.contains(name), "{}", name);
        }
    }

    #[test]
    fn test_list_references_property_unreadable_names_are_skipped(
        name in "[a-z]{1,6}",
    ) {
        prop_assume!(name != MAIN_BRANCH);
        let copy = create_repository()?;
        let commit = copy.commit_tree(&marker_tree("start"))?;
        copy.git(&["branch", "--force", &name, &commit])?;
        let mut packed_line = format!("{commit} refs/heads/").into_bytes();
        packed_line.extend_from_slice(&UNREADABLE_BRANCH_BYTES);
        packed_line.push(b'\n');
        let packed_references = copy.root.join(PACKED_REFERENCES_FILE);
        fs::write(packed_references, packed_line).map_err(to_case_error)?;

        let branches = list_branches(&copy.open_reader()?)?;

        let mut listed = branches.branches.clone();
        listed.sort();
        let mut expected = vec![MAIN_BRANCH.to_owned(), name];
        expected.sort();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_references_property_empty_listing_is_no_branches(
        extra in 0_usize..3,
    ) {
        let copy = create_repository()?;
        for index in 0..extra {
            fs::create_dir_all(copy.root.join(format!("folder-{index}")))
                .map_err(to_case_error)?;
        }

        let branches = list_branches(&copy.open_reader()?)?;

        prop_assert!(branches.branches.is_empty());
        prop_assert!(branches.task_branches.is_empty());
    }
}
