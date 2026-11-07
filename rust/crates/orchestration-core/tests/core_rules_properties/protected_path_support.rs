use orchestration_core::protected_files::ProtectedFiles;
use proptest::collection::vec;
use proptest::prelude::*;

pub const HOME: &str = "/home/ann";
const MAXIMUM_SEGMENTS: usize = 4;

pub fn path_segment() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-z][a-z.]{0,4}",
        Just(".env".to_owned()),
        Just(".ssh".to_owned()),
        Just("home".to_owned()),
        Just("ann".to_owned()),
    ]
}

pub fn path_segments() -> impl Strategy<Value = Vec<String>> {
    vec(path_segment(), 1..MAXIMUM_SEGMENTS)
}

pub fn pattern_list() -> impl Strategy<Value = ProtectedFiles> {
    let pattern = prop_oneof![
        Just(".env".to_owned()),
        Just("~/.ssh".to_owned()),
        Just("/home/ann/notes".to_owned()),
        Just("a*/b".to_owned()),
        Just("**/secret?".to_owned()),
        "(~/|/)?[a-z.*]{1,4}",
    ];
    vec(pattern, 1..4).prop_map(|patterns| ProtectedFiles { patterns })
}

pub fn absolute(segments: &[String]) -> String {
    format!("/{}", segments.join("/"))
}

pub fn insert_after(
    segments: &[String],
    position: prop::sample::Index,
    inserted: &[&str],
) -> Vec<String> {
    let split_at = position.index(segments.len() + 1);
    let mut padded: Vec<String> = segments[..split_at].to_vec();
    for segment in inserted {
        padded.push((*segment).to_owned());
    }
    padded.extend(segments[split_at..].iter().cloned());
    padded
}
