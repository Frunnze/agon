use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::PatternPlace;
use proptest::collection::vec;
use proptest::prelude::*;

pub const HOME: &str = "/home/ann";
const WORK_FOLDER: &str = "/work";
const HOME_PREFIX: &str = "~/";
const SEPARATOR: &str = "/";
const CURRENT_FOLDER_PREFIX: &str = "./";
const ANY_CHARACTERS: char = '*';
const ONE_CHARACTER: char = '?';
const EXAMPLE_NAME: &str = "x";
const MOST_SEGMENTS: usize = 4;
const MOST_EXTRA_SLASHES: usize = 3;
const MOST_SEGMENT_CHARACTERS: usize = 7;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PatternShape {
    pub place: PatternPlace,
    pub segments: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct Spelling {
    extra_slashes: Vec<usize>,
    has_dot_folder: Vec<bool>,
    has_trailing_slash: bool,
    is_uppercase: Vec<bool>,
}

pub fn pattern_place() -> impl Strategy<Value = PatternPlace> {
    prop_oneof![
        Just(PatternPlace::UnderHome),
        Just(PatternPlace::FromRoot),
        Just(PatternPlace::AtAnyDepth),
    ]
}

pub fn pattern_segments() -> impl Strategy<Value = Vec<String>> {
    vec("[a-z*?_][a-z0-9.*?_-]{0,6}", 1..=MOST_SEGMENTS)
}

pub fn pattern_shape() -> impl Strategy<Value = PatternShape> {
    (pattern_place(), pattern_segments())
        .prop_map(|(place, segments)| PatternShape { place, segments })
}

pub fn spelling() -> impl Strategy<Value = Spelling> {
    (
        vec(0..=MOST_EXTRA_SLASHES, MOST_SEGMENTS),
        vec(any::<bool>(), MOST_SEGMENTS),
        any::<bool>(),
        vec(any::<bool>(), MOST_SEGMENT_CHARACTERS),
    )
        .prop_map(
            |(
                extra_slashes,
                has_dot_folder,
                has_trailing_slash,
                is_uppercase,
            )| {
                Spelling {
                    extra_slashes,
                    has_dot_folder,
                    has_trailing_slash,
                    is_uppercase,
                }
            },
        )
}

pub fn slash_spelling() -> impl Strategy<Value = Spelling> {
    spelling().prop_map(|random_spelling| Spelling {
        is_uppercase: vec![false; MOST_SEGMENT_CHARACTERS],
        ..random_spelling
    })
}

pub fn letter_case_spelling() -> impl Strategy<Value = Spelling> {
    spelling().prop_map(|random_spelling| Spelling {
        extra_slashes: vec![0; MOST_SEGMENTS],
        has_dot_folder: vec![false; MOST_SEGMENTS],
        has_trailing_slash: false,
        ..random_spelling
    })
}

pub fn spell_pattern(shape: &PatternShape, spelling: &Spelling) -> String {
    let mut pattern = place_prefix(shape.place).to_owned();
    for (position, segment) in shape.segments.iter().enumerate() {
        let is_first = position == 0;
        if !is_first {
            pattern.push_str(SEPARATOR);
        }

        let keeps_any_depth =
            is_first && shape.place == PatternPlace::AtAnyDepth;
        if !keeps_any_depth {
            let extra_slashes = spelling.extra_slashes[position];
            pattern.push_str(&SEPARATOR.repeat(extra_slashes));
        }

        if spelling.has_dot_folder[position] {
            pattern.push_str(CURRENT_FOLDER_PREFIX);
        }
        let respelled_segment =
            change_letter_case(segment, &spelling.is_uppercase);
        pattern.push_str(&respelled_segment);
    }

    if spelling.has_trailing_slash {
        pattern.push_str(SEPARATOR);
    }
    pattern
}

pub fn example_path(shape: &PatternShape) -> String {
    let mut path = match shape.place {
        PatternPlace::UnderHome => HOME.to_owned(),
        PatternPlace::FromRoot => String::new(),
        PatternPlace::AtAnyDepth => WORK_FOLDER.to_owned(),
    };
    for segment in &shape.segments {
        let with_any_characters_filled =
            segment.replace(ANY_CHARACTERS, EXAMPLE_NAME);
        let name =
            with_any_characters_filled.replace(ONE_CHARACTER, EXAMPLE_NAME);
        path.push_str(SEPARATOR);
        path.push_str(&name);
    }
    path
}

pub fn only_patterns(patterns: &[String]) -> ProtectedFiles {
    ProtectedFiles {
        patterns: patterns.to_vec(),
    }
}

fn place_prefix(place: PatternPlace) -> &'static str {
    match place {
        PatternPlace::UnderHome => HOME_PREFIX,
        PatternPlace::FromRoot => SEPARATOR,
        PatternPlace::AtAnyDepth => "",
    }
}

fn change_letter_case(segment: &str, is_uppercase: &[bool]) -> String {
    let mut respelled_segment = String::new();
    for (position, character) in segment.chars().enumerate() {
        if is_uppercase[position] {
            respelled_segment.push(character.to_ascii_uppercase());
        } else {
            respelled_segment.push(character.to_ascii_lowercase());
        }
    }
    respelled_segment
}
