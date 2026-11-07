use std::collections::{BTreeMap, BTreeSet};
use std::fs;

use orchestration_hub::branch_names::TASK_BRANCH_PREFIX;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::raw_trees::{RAW_TREE_CASES, any_unreadable_names};
use crate::repository_copies::{
    CaseResult, MAIN_BRANCH, RepositoryCopy, create_repository, list_branches,
};

const PACKED_REFERENCES_FILE: &str = ".git/packed-refs";
const LOCAL_REFERENCE_PREFIX: &[u8] = b"refs/heads/";
const REMOTE_REFERENCE_PREFIX: &[u8] = b"refs/remotes/origin/";
const MARKER_FILE: &str = "marker.txt";
const REPLACEMENT_CHARACTER: char = '\u{FFFD}';

fn any_branch_names() -> impl Strategy<Value = BTreeSet<String>> {
    let plain = "b-[a-z0-9]{0,6}";
    let task = "t-[a-z0-9]{0,6}"
        .prop_map(|name| format!("{TASK_BRANCH_PREFIX}{name}"));
    proptest::collection::btree_set(
        prop_oneof![plain.boxed(), task.boxed()],
        0..4,
    )
}

fn start_repository(
    names: &BTreeSet<String>,
) -> CaseResult<(RepositoryCopy, String)> {
    let copy = create_repository()?;
    let marker = BTreeMap::from([(MARKER_FILE.to_owned(), b"m".to_vec())]);
    let commit = copy.commit_tree(&marker)?;
    for name in names {
        copy.git(&["branch", "--force", name, &commit])?;
    }
    Ok((copy, commit))
}

fn pack_unreadable_references(
    copy: &RepositoryCopy,
    commit: &str,
    names: &BTreeSet<Vec<u8>>,
) -> CaseResult<()> {
    let mut packed = Vec::new();
    for name in names {
        for prefix in [LOCAL_REFERENCE_PREFIX, REMOTE_REFERENCE_PREFIX] {
            packed.extend_from_slice(commit.as_bytes());
            packed.push(b' ');
            packed.extend_from_slice(prefix);
            packed.extend_from_slice(name);
            packed.push(b'\n');
        }
    }
    let packed_references = copy.root.join(PACKED_REFERENCES_FILE);
    fs::write(packed_references, packed).map_err(to_case_error)
}

fn every_listed_branch(copy: &RepositoryCopy) -> CaseResult<Vec<String>> {
    let branches = list_branches(&copy.open_reader()?)?;
    let mut names = branches.branches;
    names.extend(branches.task_branches);
    Ok(names)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RAW_TREE_CASES))]

    #[test]
    fn test_list_references_property_unreadable_references_hide_nothing(
        names in any_branch_names(),
        unreadable in any_unreadable_names(),
    ) {
        let (copy, commit) = start_repository(&names)?;
        let before = list_branches(&copy.open_reader()?)?;

        pack_unreadable_references(&copy, &commit, &unreadable)?;
        let after = list_branches(&copy.open_reader()?)?;

        prop_assert_eq!(after, before);
    }

    #[test]
    fn test_list_references_property_every_listed_branch_reads(
        names in any_branch_names(),
        unreadable in any_unreadable_names(),
    ) {
        let (copy, commit) = start_repository(&names)?;
        pack_unreadable_references(&copy, &commit, &unreadable)?;
        let reader = copy.open_reader()?;

        let listed = every_listed_branch(&copy)?;

        let mut expected = names.clone();
        expected.insert(MAIN_BRANCH.to_owned());
        let listed_set: BTreeSet<String> = listed.iter().cloned().collect();
        prop_assert_eq!(listed_set, expected);
        for branch in &listed {
            let read = reader.read_file(branch, MARKER_FILE);
            prop_assert!(read.is_ok(), "{}: {:?}", branch, read);
        }
    }

    #[test]
    fn test_list_references_property_replacement_named_branch_is_kept(
        stem in "b-[a-z]{1,6}",
        invalid_byte in prop_oneof![0x80_u8..0xC2, 0xF5_u8..=0xFF],
    ) {
        let shown_branch = format!("{stem}{REPLACEMENT_CHARACTER}");
        let names = BTreeSet::from([shown_branch.clone()]);
        let (copy, commit) = start_repository(&names)?;
        let mut twin = stem.into_bytes();
        twin.push(invalid_byte);
        pack_unreadable_references(&copy, &commit, &BTreeSet::from([twin]))?;
        let reader = copy.open_reader()?;

        let listed = every_listed_branch(&copy)?;

        let shown_count =
            listed.iter().filter(|name| **name == shown_branch).count();
        prop_assert_eq!(shown_count, 1, "{:?}", listed);
        let read = reader.read_file(&shown_branch, MARKER_FILE);
        prop_assert!(read.is_ok(), "{:?}", read);
    }
}
