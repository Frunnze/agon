use std::collections::{BTreeMap, BTreeSet};
use std::fs;

use orchestration_hub::branch_names::TASK_BRANCH_PREFIX;
use orchestration_hub::repository_reading::RepositoryReadError;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::repository_copies::{
    CaseResult, MAIN_BRANCH, REPOSITORY_CASES, RepositoryCopy,
    create_repository, list_branches,
};

const PACKED_REFERENCES_FILE: &str = ".git/packed-refs";
const LOCAL_REFERENCE_PREFIX: &str = "refs/heads/";
const REMOTE_REFERENCE_PREFIX: &str = "refs/remotes/origin/";
const MARKER_FILE: &str = "marker.txt";
const REPLACEMENT_CHARACTER: char = '\u{FFFD}';

fn any_unreadable_name() -> impl Strategy<Value = Vec<u8>> {
    let invalid_byte = prop_oneof![0x80_u8..0xC2, 0xF5_u8..=0xFF];
    ("[a-z]{0,4}", invalid_byte, "[a-z]{0,4}").prop_map(
        |(before, invalid_byte, after)| {
            let mut name = before.into_bytes();
            name.push(invalid_byte);
            name.extend_from_slice(after.as_bytes());
            name
        },
    )
}

fn any_readable_names() -> impl Strategy<Value = BTreeSet<String>> {
    let plain = "[a-z][a-z0-9-]{0,6}";
    let task = plain.prop_map(|name| format!("{TASK_BRANCH_PREFIX}{name}"));
    proptest::collection::btree_set(
        prop_oneof![plain.boxed(), task.boxed()],
        0..4,
    )
    .prop_filter("names are neither main nor a branch folder", |names| {
        !names.contains(MAIN_BRANCH) && !names.contains("task")
    })
}

fn pack_unreadable_reference(
    copy: &RepositoryCopy,
    commit: &str,
    prefix: &str,
    name: &[u8],
) -> CaseResult<()> {
    let mut packed_line = format!("{commit} {prefix}").into_bytes();
    packed_line.extend_from_slice(name);
    packed_line.push(b'\n');
    let packed_references = copy.root.join(PACKED_REFERENCES_FILE);
    fs::write(packed_references, packed_line).map_err(to_case_error)
}

fn start_repository(names: &BTreeSet<String>) -> CaseResult<RepositoryCopy> {
    let copy = create_repository()?;
    let marker = BTreeMap::from([(MARKER_FILE.to_owned(), b"m".to_vec())]);
    let commit = copy.commit_tree(&marker)?;
    for name in names {
        copy.git(&["branch", "--force", name, &commit])?;
    }
    Ok(copy)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPOSITORY_CASES))]

    #[test]
    fn test_list_branches_property_unreadable_name_is_skipped(
        names in any_readable_names(),
        unreadable in any_unreadable_name(),
        prefix in prop_oneof![
            Just(LOCAL_REFERENCE_PREFIX),
            Just(REMOTE_REFERENCE_PREFIX),
        ],
    ) {
        let copy = start_repository(&names)?;
        let commit = copy.git(&["rev-parse", "HEAD"])?;
        pack_unreadable_reference(&copy, &commit, prefix, &unreadable)?;

        let branches = list_branches(&copy.open_reader()?)?;

        let mut expected = names.clone();
        expected.insert(MAIN_BRANCH.to_owned());
        let listed: BTreeSet<String> = branches.branches.iter()
            .chain(&branches.task_branches).cloned().collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_branches_property_unreadable_task_name_is_never_offered(
        names in any_readable_names(),
        unreadable in any_unreadable_name(),
    ) {
        let copy = start_repository(&names)?;
        let commit = copy.git(&["rev-parse", "HEAD"])?;
        let mut task_name = TASK_BRANCH_PREFIX.as_bytes().to_vec();
        task_name.extend_from_slice(&unreadable);
        pack_unreadable_reference(
            &copy, &commit, LOCAL_REFERENCE_PREFIX, &task_name,
        )?;

        let branches = list_branches(&copy.open_reader()?)?;

        let has_replacement = branches.branches.iter()
            .chain(&branches.task_branches)
            .any(|name| name.contains(REPLACEMENT_CHARACTER));
        prop_assert!(!has_replacement);
        let is_task = |name: &String| name.starts_with(TASK_BRANCH_PREFIX);
        let expected_tasks = names.iter().filter(|name| is_task(name)).count();
        prop_assert_eq!(branches.task_branches.len(), expected_tasks);
    }

    #[test]
    fn test_list_branches_property_unreadable_name_cannot_be_read(
        unreadable in any_unreadable_name(),
    ) {
        let copy = start_repository(&BTreeSet::new())?;
        let commit = copy.git(&["rev-parse", "HEAD"])?;
        pack_unreadable_reference(
            &copy, &commit, LOCAL_REFERENCE_PREFIX, &unreadable,
        )?;
        let reader = copy.open_reader()?;
        let lossy_name = String::from_utf8_lossy(&unreadable).into_owned();

        let read = reader.read_file(&lossy_name, MARKER_FILE);
        let main_file = reader.read_file(MAIN_BRANCH, MARKER_FILE);

        let is_unknown =
            matches!(read, Err(RepositoryReadError::UnknownBranch(_)));
        prop_assert!(is_unknown, "{:?}", read);
        prop_assert!(main_file.is_ok(), "{:?}", main_file);
    }
}
