use std::sync::{Arc, Mutex};

use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use orchestration_node::agent_login::LoginProgress;
use orchestration_node::node::Node;
use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice,
    NodeConfiguration, PeerRelayChoice,
};
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

const DEBUG_CASES: u32 = 64;
const NODE_CASES: u32 = 8;
const TOKEN_START: &str = "sk-ant-oat01-";
const TOKEN_HEADING: &str = "Your OAuth token (valid for 1 year):";
const BOLD_START: &str = "\u{1b}[1m";
const STYLE_END: &str = "\u{1b}[0m";
const LINE_END: &str = "\r\n";

fn any_secret() -> impl Strategy<Value = String> {
    "[A-Za-z0-9]{12,40}[_-]?[A-Za-z0-9]{12,40}"
}

fn any_screen_marker() -> impl Strategy<Value = String> {
    "[A-Za-z0-9]{24,40}"
}

fn any_chunk_lengths() -> impl Strategy<Value = Vec<usize>> {
    proptest::collection::vec(1_usize..16, 1..24)
}

fn keep_letters_and_digits(text: &str) -> String {
    let mut kept = String::new();
    for character in text.chars() {
        if character.is_alphanumeric() {
            kept.push(character);
        }
    }
    kept
}

fn split_into_chunks(text: &str, chunk_lengths: &[usize]) -> Vec<String> {
    let characters: Vec<char> = text.chars().collect();
    let mut chunks = Vec::new();
    let mut start = 0;
    let mut length_index = 0;
    while start < characters.len() {
        let length = chunk_lengths[length_index % chunk_lengths.len()];
        let end = (start + length).min(characters.len());
        chunks.push(characters[start..end].iter().collect());
        start = end;
        length_index += 1;
    }
    chunks
}

fn build_token_screen(marker: &str, secret: &str) -> String {
    format!(
        "{marker}{LINE_END}{TOKEN_HEADING}{LINE_END}{LINE_END}\
         {BOLD_START}{TOKEN_START}{secret}{STYLE_END}{LINE_END}"
    )
}

fn feed_progress(output: &str, chunk_lengths: &[usize]) -> LoginProgress {
    let mut progress = LoginProgress::default();
    for chunk in split_into_chunks(output, chunk_lengths) {
        progress.take_output(&chunk);
    }
    progress
}

fn shows_text(debug_output: &str, hidden_text: &str) -> bool {
    let shown = keep_letters_and_digits(debug_output);
    shown.contains(&keep_letters_and_digits(hidden_text))
}

fn open_bare_node(data_directory: &TempDir) -> Result<Node, TestCaseError> {
    let configuration = NodeConfiguration {
        data_directory: data_directory.path().to_path_buf(),
        identity_store: IdentityStoreChoice::File,
        runner: None,
        peer_relay: PeerRelayChoice::Disabled,
        app_server_port: DEFAULT_APP_SERVER_PORT,
        server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
    };
    Node::open(&configuration).map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DEBUG_CASES))]

    #[test]
    fn test_login_progress_fmt_property_never_shows_the_seen_token(
        marker in any_screen_marker(),
        secret in any_secret(),
        chunk_lengths in any_chunk_lengths(),
    ) {
        let output = build_token_screen(&marker, &secret);

        let progress = feed_progress(&output, &chunk_lengths);

        let shared_progress = Arc::new(Mutex::new(progress));
        for debug_output in [
            format!("{shared_progress:?}"),
            format!("{shared_progress:#?}"),
        ] {
            let is_shown = shows_text(&debug_output, &secret);
            prop_assert!(!is_shown, "{debug_output}");
        }
    }

    #[test]
    fn test_login_progress_fmt_property_leaves_the_screen_out(
        marker in any_screen_marker(),
        secret in any_secret(),
        chunk_lengths in any_chunk_lengths(),
    ) {
        let output = build_token_screen(&marker, &secret);

        let progress = feed_progress(&output, &chunk_lengths);

        let debug_output = format!("{progress:?}");
        prop_assert!(!shows_text(&debug_output, &marker), "{debug_output}");
        prop_assert!(debug_output.starts_with("LoginProgress"));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_node_fmt_property_never_shows_a_kept_token(
        secret in any_secret(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_bare_node(&data_directory)?;
        let token = format!("{TOKEN_START}{secret}");
        let credential =
            AgentCredential::new(AgentCredentialKind::LongLivedToken, &token)
                .map_err(fail)?;

        node.agent_credentials().keep(credential).map_err(fail)?;

        let debug_output = format!("{node:#?}");
        prop_assert!(!shows_text(&debug_output, &secret), "{debug_output}");
    }
}
