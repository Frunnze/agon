use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use orchestration_core::identifiers::DeviceId;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::canonical_message::{encode_canonical_message, encode_timestamp};
use crate::error::{AuditChainProblem, SecurityError};
use crate::identity::{DeviceIdentity, verify_signature};

pub const GENESIS_HASH: &str =
    "0000000000000000000000000000000000000000000000000000000000000000";
const AUDIT_ENTRY_DOMAIN: &str = "orchestration-audit-entry-v1";

pub type SignerKeys = BTreeMap<DeviceId, Vec<u8>>;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuditEntry {
    pub index: usize,
    pub at: DateTime<Utc>,
    pub device_id: DeviceId,
    pub event: String,
    #[serde(default)]
    pub detail: Option<String>,
    pub previous_hash: String,
    pub hash: String,
    pub signature: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChainSummary {
    pub entry_count: usize,
    pub head_hash: String,
}

struct EntryContent<'entry> {
    index: usize,
    at: DateTime<Utc>,
    device_id: &'entry DeviceId,
    event: &'entry str,
    detail: Option<&'entry str>,
    previous_hash: &'entry str,
}

#[must_use]
pub fn append_entry(
    chain: &[AuditEntry],
    identity: &DeviceIdentity,
    event: String,
    detail: Option<String>,
    at: DateTime<Utc>,
) -> AuditEntry {
    let previous_hash = chain
        .last()
        .map_or_else(|| GENESIS_HASH.to_owned(), |entry| entry.hash.clone());
    let device_id = identity.device_id();
    let content = EntryContent {
        index: chain.len(),
        at,
        device_id: &device_id,
        event: &event,
        detail: detail.as_deref(),
        previous_hash: &previous_hash,
    };
    let message = encode_entry_content(&content);

    AuditEntry {
        index: content.index,
        at,
        hash: hash_message(&message),
        signature: identity.sign(&message),
        device_id,
        event,
        detail,
        previous_hash,
    }
}

pub fn verify_chain(
    chain: &[AuditEntry],
    signer_keys: &SignerKeys,
) -> Result<ChainSummary, SecurityError> {
    verify_chain_suffix(chain, 0, signer_keys)
}

pub fn verify_chain_suffix(
    chain: &[AuditEntry],
    verified_length: usize,
    signer_keys: &SignerKeys,
) -> Result<ChainSummary, SecurityError> {
    let Some((verified_part, _)) = chain.split_at_checked(verified_length)
    else {
        return Err(SecurityError::AuditChainBroken {
            index: chain.len(),
            problem: AuditChainProblem::WrongIndex,
        });
    };
    let mut expected_previous_hash = verified_part
        .last()
        .map_or(GENESIS_HASH, |entry| entry.hash.as_str());
    for (position, entry) in chain.iter().enumerate().skip(verified_length) {
        verify_entry(entry, position, expected_previous_hash, signer_keys)
            .map_err(|problem| SecurityError::AuditChainBroken {
                index: position,
                problem,
            })?;
        expected_previous_hash = &entry.hash;
    }

    Ok(ChainSummary {
        entry_count: chain.len(),
        head_hash: expected_previous_hash.to_owned(),
    })
}

fn verify_entry(
    entry: &AuditEntry,
    position: usize,
    expected_previous_hash: &str,
    signer_keys: &SignerKeys,
) -> Result<(), AuditChainProblem> {
    if entry.index != position {
        return Err(AuditChainProblem::WrongIndex);
    }
    if entry.previous_hash != expected_previous_hash {
        return Err(AuditChainProblem::WrongPreviousHash);
    }

    let content = EntryContent {
        index: entry.index,
        at: entry.at,
        device_id: &entry.device_id,
        event: &entry.event,
        detail: entry.detail.as_deref(),
        previous_hash: &entry.previous_hash,
    };
    let message = encode_entry_content(&content);
    if hash_message(&message) != entry.hash {
        return Err(AuditChainProblem::WrongHash);
    }

    let signer_key = signer_keys
        .get(&entry.device_id)
        .ok_or(AuditChainProblem::UnknownSigner)?;
    verify_signature(signer_key, &message, &entry.signature)
        .map_err(|_| AuditChainProblem::InvalidSignature)
}

fn encode_entry_content(content: &EntryContent<'_>) -> Vec<u8> {
    let index = (content.index as u64).to_be_bytes();
    let at = encode_timestamp(content.at);
    let mut parts: Vec<&[u8]> = vec![
        &index,
        &at,
        content.device_id.0.as_bytes(),
        content.event.as_bytes(),
        content.previous_hash.as_bytes(),
    ];
    if let Some(detail) = content.detail {
        parts.push(detail.as_bytes());
    }
    encode_canonical_message(AUDIT_ENTRY_DOMAIN, &parts)
}

fn hash_message(message: &[u8]) -> String {
    hex::encode(Sha256::digest(message))
}
