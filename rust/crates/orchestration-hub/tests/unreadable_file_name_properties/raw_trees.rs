use std::collections::{BTreeMap, BTreeSet};
use std::io::Write;
use std::process::{Command, Stdio};

use orchestration_core::repository_files::{
    FilePreview, RepositoryEntry, RepositoryEntryKind,
};
use orchestration_hub::repository_reading::RepositoryReader;
use proptest::prelude::*;

use crate::hook_running::to_case_error;
use crate::repository_copies::{
    CaseResult, MAIN_BRANCH, RepositoryCopy, create_repository,
};

pub type RawTree = BTreeMap<Vec<u8>, RawNode>;

#[derive(Clone, Debug)]
pub enum RawNode {
    File(Vec<u8>),
    Folder(RawTree),
}

pub const RAW_TREE_CASES: u32 = 8;

const GIT_PROGRAM: &str = "git";
const CEILING_VARIABLE: &str = "GIT_CEILING_DIRECTORIES";
const FILE_LINE_START: &[u8] = b"100644 blob ";
const FOLDER_LINE_START: &[u8] = b"040000 tree ";
const NAME_SEPARATOR: u8 = b'\t';
const ENTRY_END: u8 = 0;
const COMMIT_MESSAGE: &str = "Store raw names";
const LOCAL_BRANCHES: &str = "refs/heads/";

fn run_git_with_input(
    copy: &RepositoryCopy,
    arguments: &[&str],
    input: &[u8],
) -> CaseResult<String> {
    let ceiling = copy.root.parent().unwrap_or(&copy.root);
    let mut child = Command::new(GIT_PROGRAM)
        .args(arguments)
        .current_dir(&copy.root)
        .env(CEILING_VARIABLE, ceiling)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(to_case_error)?;
    let mut git_input = child
        .stdin
        .take()
        .ok_or_else(|| to_case_error("git takes no input"))?;
    git_input.write_all(input).map_err(to_case_error)?;
    drop(git_input);

    let output = child.wait_with_output().map_err(to_case_error)?;
    if !output.status.success() {
        let problem = String::from_utf8_lossy(&output.stderr).into_owned();
        return Err(to_case_error(problem));
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

fn write_tree(copy: &RepositoryCopy, tree: &RawTree) -> CaseResult<String> {
    let mut listing = Vec::new();
    for (name, node) in tree {
        let (line_start, object) = match node {
            RawNode::File(content) => {
                let arguments = ["hash-object", "-w", "--stdin"];
                let blob = run_git_with_input(copy, &arguments, content)?;
                (FILE_LINE_START, blob)
            }
            RawNode::Folder(inner_tree) => {
                (FOLDER_LINE_START, write_tree(copy, inner_tree)?)
            }
        };
        listing.extend_from_slice(line_start);
        listing.extend_from_slice(object.as_bytes());
        listing.push(NAME_SEPARATOR);
        listing.extend_from_slice(name);
        listing.push(ENTRY_END);
    }
    run_git_with_input(copy, &["mktree", "-z"], &listing)
}

pub fn commit_raw_tree(tree: &RawTree) -> CaseResult<RepositoryCopy> {
    let copy = create_repository()?;
    let tree_object = write_tree(&copy, tree)?;
    let commit_arguments =
        ["commit-tree", tree_object.as_str(), "-m", COMMIT_MESSAGE];
    let commit = copy.git(&commit_arguments)?;
    let reference = format!("{LOCAL_BRANCHES}{MAIN_BRANCH}");
    copy.git(&["update-ref", &reference, &commit])?;
    Ok(copy)
}

pub fn files_named(names: &BTreeSet<Vec<u8>>, content: &[u8]) -> RawTree {
    let mut tree = RawTree::new();
    for name in names {
        tree.insert(name.clone(), RawNode::File(content.to_vec()));
    }
    tree
}

pub fn readable_files(names: &BTreeSet<String>) -> RawTree {
    let mut tree = RawTree::new();
    for name in names {
        let content = name.as_bytes().to_vec();
        tree.insert(name.clone().into_bytes(), RawNode::File(content));
    }
    tree
}

pub fn list_root(
    reader: &RepositoryReader,
) -> CaseResult<Vec<RepositoryEntry>> {
    reader.list_folder(MAIN_BRANCH, "").map_err(to_case_error)
}

pub fn listed_names(entries: &[RepositoryEntry]) -> BTreeSet<String> {
    let mut names = BTreeSet::new();
    for entry in entries {
        names.insert(entry.name.clone());
    }
    names
}

pub fn read_main_text(
    reader: &RepositoryReader,
    path: &str,
) -> CaseResult<String> {
    let file = reader.read_file(MAIN_BRANCH, path).map_err(to_case_error)?;
    let FilePreview::Text { text } = file.preview else {
        return Err(to_case_error(format!("{path} is not text")));
    };
    Ok(text)
}

pub fn is_folder(entry: &RepositoryEntry) -> bool {
    entry.kind == RepositoryEntryKind::Folder
}

pub fn any_unreadable_name() -> impl Strategy<Value = Vec<u8>> {
    let broken_sequence = prop_oneof![
        (0xF5_u8..=0xFF).prop_map(|byte| vec![byte]),
        (0x80_u8..0xC0).prop_map(|byte| vec![byte]),
        Just(vec![0xC0, 0xAF]),
        Just(vec![0xE2, 0x82]),
        Just(vec![0xED, 0xA0, 0x80]),
        Just(vec![0xF0, 0x9F, 0x98]),
    ];
    ("[a-z]{0,4}", broken_sequence, "[a-z.]{0,4}").prop_map(
        |(before, broken_sequence, after)| {
            let mut name = before.into_bytes();
            name.extend_from_slice(&broken_sequence);
            name.extend_from_slice(after.as_bytes());
            name
        },
    )
}

pub fn any_unreadable_names() -> impl Strategy<Value = BTreeSet<Vec<u8>>> {
    proptest::collection::btree_set(any_unreadable_name(), 1..4)
}

pub fn any_readable_names() -> impl Strategy<Value = BTreeSet<String>> {
    let name = "[a-zA-Z0-9][a-zA-Z0-9 ._é中\u{FFFD}-]{0,8}";
    proptest::collection::btree_set(name, 0..5)
}
