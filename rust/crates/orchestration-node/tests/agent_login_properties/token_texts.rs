use proptest::prelude::*;

pub const TOKEN_PREFIX: &str = "sk-ant-oat";
pub const HIDDEN_TOKEN: &str = "sk-ant-••••••••";
const TOKEN_FRAGMENTS: [&str; 16] = [
    "sk-ant-oat",
    "sk-ant-oat01-",
    "sk-ant-",
    "oat",
    "0",
    "7",
    "-",
    "-",
    "_",
    "a",
    "Z",
    " ",
    "\n",
    "é",
    "•",
    "sk-ant-••••••••",
];
const OTHER_CHARACTERS: [char; 10] = [
    ' ', '\n', '.', ':', '>', 'é', '•', '٣', '\u{3000}', '\u{ff21}',
];

pub fn any_token() -> impl Strategy<Value = String> {
    "sk-ant-oat[0-9]{1,3}-[A-Za-z0-9_-]{1,100}"
}

pub fn any_long_secret_token() -> impl Strategy<Value = String> {
    "sk-ant-oat0[1-9]-[A-Za-z0-9]{24,60}"
}

pub fn any_other_character() -> impl Strategy<Value = char> {
    proptest::sample::select(OTHER_CHARACTERS.to_vec())
}

pub fn any_tokenless_text() -> impl Strategy<Value = String> {
    proptest::collection::vec(any_other_character(), 0..6)
        .prop_map(|characters| characters.into_iter().collect())
}

pub fn any_hostile_token_text() -> impl Strategy<Value = String> {
    let fragment = prop_oneof![
        4 => proptest::sample::select(TOKEN_FRAGMENTS.to_vec())
            .prop_map(str::to_owned),
        1 => any_token(),
        1 => any::<char>().prop_map(String::from),
    ];
    proptest::collection::vec(fragment, 0..16)
        .prop_map(|fragments| fragments.concat())
}

#[derive(Clone, Copy, Debug)]
struct CharacterRun<'text> {
    is_token: bool,
    text: &'text str,
}

pub fn is_token_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == '-' || character == '_'
}

fn is_valid_token_start(run_rest: &str) -> bool {
    let Some(after_prefix) = run_rest.strip_prefix(TOKEN_PREFIX) else {
        return false;
    };
    let after_version = after_prefix
        .trim_start_matches(|character: char| character.is_ascii_digit());
    let has_version = after_version.len() < after_prefix.len();
    let secret = after_version.strip_prefix('-').unwrap_or_default();
    has_version && !secret.is_empty()
}

fn find_token_start(run: CharacterRun<'_>) -> Option<usize> {
    if !run.is_token {
        return None;
    }
    for (start, _) in run.text.char_indices() {
        if is_valid_token_start(&run.text[start..]) {
            return Some(start);
        }
    }
    None
}

fn split_character_runs(text: &str) -> Vec<CharacterRun<'_>> {
    let mut runs = Vec::new();
    let mut run_start = 0;
    let mut previous_is_token: Option<bool> = None;
    for (index, character) in text.char_indices() {
        let is_token = is_token_character(character);
        if let Some(previous) = previous_is_token
            && previous != is_token
        {
            let run_text = &text[run_start..index];
            runs.push(CharacterRun {
                is_token: previous,
                text: run_text,
            });
            run_start = index;
        }
        previous_is_token = Some(is_token);
    }
    if let Some(previous) = previous_is_token {
        let run_text = &text[run_start..];
        runs.push(CharacterRun {
            is_token: previous,
            text: run_text,
        });
    }
    runs
}

pub fn expect_tokens(text: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    for run in split_character_runs(text) {
        if let Some(start) = find_token_start(run) {
            tokens.push(run.text[start..].to_owned());
        }
    }
    tokens
}

pub fn expect_hidden_text(text: &str) -> String {
    let mut hidden = String::new();
    for run in split_character_runs(text) {
        match find_token_start(run) {
            Some(start) => {
                hidden.push_str(&run.text[..start]);
                hidden.push_str(HIDDEN_TOKEN);
            }
            None => hidden.push_str(run.text),
        }
    }
    hidden
}
