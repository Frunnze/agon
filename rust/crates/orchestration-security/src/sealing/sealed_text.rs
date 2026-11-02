use crate::error::SecurityError;
use crate::sealing::workspace_key::WorkspaceKey;

pub const SEALED_TEXT_PREFIX: &str = "sealed-v1:";

pub fn seal_text(
    workspace_key: &WorkspaceKey,
    text: &str,
) -> Result<String, SecurityError> {
    let encrypted = workspace_key.encrypt(text.as_bytes())?;
    Ok(format!("{SEALED_TEXT_PREFIX}{}", hex::encode(encrypted)))
}

pub fn open_text(
    workspace_key: &WorkspaceKey,
    sealed_text: &str,
) -> Result<String, SecurityError> {
    let encoded = sealed_text
        .strip_prefix(SEALED_TEXT_PREFIX)
        .ok_or(SecurityError::MalformedSealedText)?;
    let encrypted = hex::decode(encoded)
        .map_err(|_| SecurityError::MalformedSealedText)?;

    let plaintext = workspace_key.decrypt(&encrypted)?;

    String::from_utf8(plaintext)
        .map_err(|_| SecurityError::MalformedSealedText)
}
