use proptest::collection::vec;
use proptest::prelude::*;

pub const RULE_WORD: &str = "rule";
const WHITESPACE_CHARACTERS: [char; 6] =
    [' ', '\t', '\n', '\u{a0}', '\u{2003}', '\u{3000}'];
const MOST_WHITESPACE: usize = 5;

pub fn blank_title() -> impl Strategy<Value = String> {
    vec(
        prop::sample::select(&WHITESPACE_CHARACTERS[..]),
        0..=MOST_WHITESPACE,
    )
    .prop_map(|characters| characters.into_iter().collect())
}

pub fn worded_title() -> impl Strategy<Value = String> {
    (blank_title(), "[A-Za-z][a-z ]{0,20}", blank_title())
        .prop_map(|(before, words, after)| format!("{before}{words}{after}"))
}

pub fn blank_or_worded_title() -> impl Strategy<Value = String> {
    prop_oneof![blank_title(), worded_title()]
}
