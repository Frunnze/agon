use orchestration_core::protected_paths::{
    ANY_FOLDERS_SEGMENT, PatternPlace, read_protected_pattern,
};
use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::prelude::*;

const ANY_CHARACTERS: char = '*';
const ONE_CHARACTER: char = '?';
const ONE_CHARACTER_FILLING: char = 'q';
const SEPARATOR: char = '/';

#[derive(Clone, Copy, Debug)]
pub enum HostileSpelling {
    DoubledSeparator,
    CurrentFolder,
    ParentDetour,
    LeadingDetour,
    ChangedCase,
}

#[derive(Clone, Debug)]
pub struct PathFilling {
    pub names: Vec<String>,
    pub folders: Vec<String>,
    pub inside: Option<String>,
}

pub fn any_path_filling() -> impl Strategy<Value = PathFilling> {
    let names = proptest::collection::vec("[a-z0-9]{0,4}", 1..4);
    let folders = proptest::collection::vec("[a-z0-9][a-z0-9_-]{0,5}", 0..3);
    let inside = proptest::option::of("[a-z0-9][a-z0-9._-]{0,6}");
    (names, folders, inside).prop_map(|(names, folders, inside)| PathFilling {
        names,
        folders,
        inside,
    })
}

pub fn any_hostile_spelling() -> impl Strategy<Value = HostileSpelling> {
    prop_oneof![
        Just(HostileSpelling::DoubledSeparator),
        Just(HostileSpelling::CurrentFolder),
        Just(HostileSpelling::ParentDetour),
        Just(HostileSpelling::LeadingDetour),
        Just(HostileSpelling::ChangedCase),
    ]
}

fn fill_segment(segment: &str, filling: &PathFilling, index: usize) -> String {
    let mut filled = String::new();
    for character in segment.chars() {
        if character == ANY_CHARACTERS {
            filled.push_str(&filling.names[index % filling.names.len()]);
        } else if character == ONE_CHARACTER {
            filled.push(ONE_CHARACTER_FILLING);
        } else {
            filled.push(character);
        }
    }
    filled
}

pub fn spell_protected_path(
    pattern: &str,
    home: &str,
    filling: &PathFilling,
) -> String {
    let read_pattern = read_protected_pattern(pattern);
    let start = match read_pattern.place {
        PatternPlace::UnderHome => home.to_owned(),
        PatternPlace::FromRoot => String::new(),
        PatternPlace::AtAnyDepth => {
            add_folders(CONTAINER_WORKSPACE_DIRECTORY, &filling.folders)
        }
    };

    let mut path = start;
    for (index, segment) in read_pattern.segments.iter().enumerate() {
        if segment == ANY_FOLDERS_SEGMENT {
            path = add_folders(&path, &filling.folders);
            continue;
        }
        path.push(SEPARATOR);
        path.push_str(&fill_segment(segment, filling, index));
    }
    if let Some(inside) = &filling.inside {
        path.push(SEPARATOR);
        path.push_str(inside);
    }
    if path.is_empty() {
        path.push(SEPARATOR);
    }
    path
}

fn add_folders(path: &str, folders: &[String]) -> String {
    let mut longer_path = path.to_owned();
    for folder in folders {
        longer_path.push(SEPARATOR);
        longer_path.push_str(folder);
    }
    longer_path
}

fn flip_case(text: &str) -> String {
    let mut flipped = String::new();
    for character in text.chars() {
        if character.is_ascii_lowercase() {
            flipped.push(character.to_ascii_uppercase());
        } else {
            flipped.push(character.to_ascii_lowercase());
        }
    }
    flipped
}

pub fn respell_path(
    path: &str,
    spelling: HostileSpelling,
    position: usize,
) -> String {
    let separators: Vec<usize> = path
        .char_indices()
        .filter(|(_, character)| *character == SEPARATOR)
        .map(|(index, _)| index)
        .collect();
    let at = separators[position % separators.len()];
    let (before, after) = path.split_at(at);
    match spelling {
        HostileSpelling::DoubledSeparator => format!("{before}/{after}"),
        HostileSpelling::CurrentFolder => format!("{before}/.{after}"),
        HostileSpelling::ParentDetour => format!("{before}/detour/..{after}"),
        HostileSpelling::LeadingDetour => format!("/detour/..{path}"),
        HostileSpelling::ChangedCase => flip_case(path),
    }
}
