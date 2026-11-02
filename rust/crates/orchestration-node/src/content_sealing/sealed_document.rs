use orchestration_security::sealing::SEALED_TEXT_PREFIX;

use super::workspace_keyring::WorkspaceKeyring;
use crate::node_error::NodeError;

const QUOTE: char = '"';

pub fn open_sealed_document(
    keyring: &WorkspaceKeyring,
    document: &str,
) -> Result<String, NodeError> {
    let quoted_prefix = format!("{QUOTE}{SEALED_TEXT_PREFIX}");
    let mut opened_document = String::new();
    let mut remaining = document;

    while let Some(quote_position) = remaining.find(&quoted_prefix) {
        opened_document.push_str(&remaining[..quote_position]);
        let after_opening_quote = &remaining[quote_position + 1..];
        let sealed_length = after_opening_quote
            .find(QUOTE)
            .ok_or(NodeError::UnreadableSealedText)?;
        let sealed_text = &after_opening_quote[..sealed_length];

        let plain_text = keyring.open_text(sealed_text)?;
        opened_document.push_str(&serde_json::to_string(&plain_text)?);
        remaining = &after_opening_quote[sealed_length + 1..];
    }

    opened_document.push_str(remaining);
    Ok(opened_document)
}
