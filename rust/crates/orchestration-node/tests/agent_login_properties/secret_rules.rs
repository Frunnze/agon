use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use proptest::prelude::*;

pub const BLANK_SECRET_PROBLEM: &str =
    "the Claude Code token or API key cannot be empty";
pub const BROKEN_SECRET_PROBLEM: &str =
    "the token or API key cannot have spaces or line breaks";
const UNICODE_WHITE_SPACE: [char; 25] = [
    '\u{9}', '\u{a}', '\u{b}', '\u{c}', '\u{d}', '\u{20}', '\u{85}', '\u{a0}',
    '\u{1680}', '\u{2000}', '\u{2001}', '\u{2002}', '\u{2003}', '\u{2004}',
    '\u{2005}', '\u{2006}', '\u{2007}', '\u{2008}', '\u{2009}', '\u{200a}',
    '\u{2028}', '\u{2029}', '\u{202f}', '\u{205f}', '\u{3000}',
];
const FIRST_LOW_CONTROL: char = '\u{0}';
const LAST_LOW_CONTROL: char = '\u{1f}';
const FIRST_HIGH_CONTROL: char = '\u{7f}';
const LAST_HIGH_CONTROL: char = '\u{9f}';
const LOOKALIKE_CHARACTERS: [char; 6] =
    ['\u{200b}', '\u{feff}', '\u{2060}', 'é', '٣', '\u{ff21}'];

pub fn any_kind() -> impl Strategy<Value = AgentCredentialKind> {
    prop_oneof![
        Just(AgentCredentialKind::LongLivedToken),
        Just(AgentCredentialKind::ApiKey),
    ]
}

pub fn any_white_space() -> impl Strategy<Value = char> {
    proptest::sample::select(UNICODE_WHITE_SPACE.to_vec())
}

pub fn any_white_space_padding() -> impl Strategy<Value = String> {
    proptest::collection::vec(any_white_space(), 0..4)
        .prop_map(|padding| padding.into_iter().collect())
}

pub fn any_control_character() -> impl Strategy<Value = char> {
    prop_oneof![
        proptest::char::range(FIRST_LOW_CONTROL, LAST_LOW_CONTROL),
        proptest::char::range(FIRST_HIGH_CONTROL, LAST_HIGH_CONTROL),
    ]
}

pub fn any_valid_secret() -> impl Strategy<Value = String> {
    let lookalike = proptest::sample::select(LOOKALIKE_CHARACTERS.to_vec());
    let secret_character = prop_oneof![
        4 => proptest::char::range('!', '~'),
        1 => lookalike,
    ];
    proptest::collection::vec(secret_character, 1..60)
        .prop_map(|characters| characters.into_iter().collect())
}

pub fn any_hostile_text() -> impl Strategy<Value = String> {
    let hostile_character = prop_oneof![
        3 => proptest::char::range('!', '~'),
        2 => any_white_space(),
        1 => any_control_character(),
        1 => any::<char>(),
    ];
    proptest::collection::vec(hostile_character, 0..30)
        .prop_map(|characters| characters.into_iter().collect())
}

pub fn any_credential() -> impl Strategy<Value = AgentCredential> {
    (any_kind(), any_valid_secret())
        .prop_filter_map("the secret follows the rules", |(kind, secret)| {
            AgentCredential::new(kind, &secret).ok()
        })
}

pub fn is_unicode_white_space(character: char) -> bool {
    UNICODE_WHITE_SPACE.contains(&character)
}

pub fn is_control_character(character: char) -> bool {
    let is_low = (FIRST_LOW_CONTROL..=LAST_LOW_CONTROL).contains(&character);
    let is_high =
        (FIRST_HIGH_CONTROL..=LAST_HIGH_CONTROL).contains(&character);
    is_low || is_high
}

pub fn is_breaking_character(character: char) -> bool {
    is_unicode_white_space(character) || is_control_character(character)
}

pub fn trim_unicode_white_space(text: &str) -> &str {
    text.trim_matches(is_unicode_white_space)
}

pub fn expect_secret_rules(text: &str) -> Result<String, String> {
    let trimmed = trim_unicode_white_space(text);
    if trimmed.is_empty() {
        return Err(BLANK_SECRET_PROBLEM.to_owned());
    }
    if trimmed.chars().any(is_breaking_character) {
        return Err(BROKEN_SECRET_PROBLEM.to_owned());
    }
    Ok(trimmed.to_owned())
}
