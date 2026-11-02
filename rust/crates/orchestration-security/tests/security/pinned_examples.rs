use std::collections::BTreeSet;
use std::error::Error;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_security::audit::{GENESIS_HASH, append_entry};
use orchestration_security::error::SecurityError;
use orchestration_security::identity::{
    DeviceIdentity, KEY_LENGTH, device_id_for,
};
use orchestration_security::pairing::{
    FINGERPRINT_WORD_LIST, PAIRING_NONCE_LENGTH, PAIRING_SESSION_LIFETIME,
    PairingCode, PairingPublicKeys, PairingSession, PairingTranscript,
    commit_to_approver_nonce,
};
use orchestration_security::request_signing::{
    DEVICE_ID_HEADER, NONCE_HEADER, REQUEST_TIMESTAMP_WINDOW,
    SIGNATURE_HEADER, TIMESTAMP_HEADER, sign_request, verify_request,
};
use orchestration_security::sealing::{
    SEALED_TEXT_PREFIX, WorkspaceKey, seal_text,
};

type ExampleResult = Result<(), Box<dyn Error>>;

const RFC_8032_SECRET_KEY: &str =
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60";
const RFC_8032_PUBLIC_KEY: &str =
    "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a";
const RFC_8032_EMPTY_MESSAGE_SIGNATURE: &str = concat!(
    "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155",
    "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b",
);
const RFC_8032_DEVICE_ID: &str = "21fe31dfa154a261626bf854046fd227";
const KNOWN_PAIRING_CODE: &str = "4F7K2Q";
const KNOWN_FINGERPRINT_WORDS: [&str; 4] =
    ["lobster", "iceberg", "turtle", "button"];
const KNOWN_COMMITMENT: &str =
    "571c8b6be65cb7b2661bd7a364d40edcb2f91c686e5b06b710074b6306686ed7";
const JOINER_NONCE_BYTE: u8 = 5;
const APPROVER_NONCE_BYTE: u8 = 6;
const FIXED_MOMENT: &str = "2026-10-30T12:00:00Z";
const FIXED_MOMENT_HEADER: &str = "2026-10-30T12:00:00.000000000Z";
const SIGNATURE_HEX_LENGTH: usize = 128;
const NONCE_HEX_LENGTH: usize = 32;
const HASH_HEX_LENGTH: usize = 64;
const NONCE_LENGTH: usize = 24;
const TAG_LENGTH: usize = 16;
const HEX_DIGITS_PER_BYTE: usize = 2;

fn rfc_8032_identity() -> Result<DeviceIdentity, Box<dyn Error>> {
    let mut secret = hex::decode(RFC_8032_SECRET_KEY)?;
    secret.extend_from_slice(&[0; KEY_LENGTH]);
    Ok(DeviceIdentity::from_secret_bytes(&secret)?)
}

#[test]
fn pairing_code_display_is_three_symbols_dash_three_symbols() -> ExampleResult
{
    let code = PairingCode::parse("4f7 k2q")?;

    assert_eq!(code.display(), "4F7-K2Q");
    Ok(())
}

#[test]
fn pairing_code_parse_reads_ambiguous_letters_as_digits() -> ExampleResult {
    let code = PairingCode::parse("oil-OIL")?;

    assert_eq!(code.display(), "011-011");
    Ok(())
}

#[test]
fn signing_matches_rfc_8032_first_test_vector() -> ExampleResult {
    let identity = rfc_8032_identity()?;

    let signature = identity.sign(b"");

    let public_identity = identity.public_identity();
    assert_eq!(
        hex::encode(public_identity.signing_public_key),
        RFC_8032_PUBLIC_KEY
    );
    assert_eq!(hex::encode(signature), RFC_8032_EMPTY_MESSAGE_SIGNATURE);
    Ok(())
}

#[test]
fn device_id_is_hex_of_first_16_sha256_bytes_of_signing_key() -> ExampleResult
{
    let public_key = hex::decode(RFC_8032_PUBLIC_KEY)?;

    let device_id = device_id_for(&public_key);

    assert_eq!(device_id.0, RFC_8032_DEVICE_ID);
    assert_eq!(rfc_8032_identity()?.device_id().0, RFC_8032_DEVICE_ID);
    Ok(())
}

#[test]
fn fingerprint_word_list_holds_256_distinct_lowercase_words() {
    let distinct_words: BTreeSet<&str> =
        FINGERPRINT_WORD_LIST.iter().copied().collect();

    assert_eq!(distinct_words.len(), FINGERPRINT_WORD_LIST.len());
    for word in FINGERPRINT_WORD_LIST {
        assert!(word.chars().all(|character| character.is_ascii_lowercase()));
    }
}

fn known_keys(signing_byte: u8, sealing_byte: u8) -> PairingPublicKeys {
    PairingPublicKeys {
        signing_public_key: vec![signing_byte; KEY_LENGTH],
        sealing_public_key: vec![sealing_byte; KEY_LENGTH],
    }
}

fn known_transcript() -> Result<PairingTranscript, Box<dyn Error>> {
    Ok(PairingTranscript {
        code: PairingCode::parse(KNOWN_PAIRING_CODE)?,
        joiner: known_keys(1, 2),
        approver: known_keys(3, 4),
        joiner_nonce: vec![JOINER_NONCE_BYTE; PAIRING_NONCE_LENGTH],
        approver_nonce: vec![APPROVER_NONCE_BYTE; PAIRING_NONCE_LENGTH],
    })
}

#[test]
fn pairing_words_are_stable_for_a_known_transcript() -> ExampleResult {
    let words = known_transcript()?.fingerprint_words();

    assert_eq!(words, KNOWN_FINGERPRINT_WORDS);
    Ok(())
}

#[test]
fn approver_commitment_is_stable_for_known_values() -> ExampleResult {
    let transcript = known_transcript()?;

    let commitment = commit_to_approver_nonce(
        &transcript.code,
        &transcript.approver,
        &transcript.approver_nonce,
    );

    assert_eq!(hex::encode(commitment), KNOWN_COMMITMENT);
    Ok(())
}

#[test]
fn audit_chain_starts_from_all_zero_genesis_hash() -> ExampleResult {
    let identity = rfc_8032_identity()?;
    let at: DateTime<Utc> = FIXED_MOMENT.parse()?;

    let entry = append_entry(&[], &identity, "created".to_owned(), None, at);

    assert_eq!(GENESIS_HASH, "0".repeat(HASH_HEX_LENGTH));
    assert_eq!(entry.previous_hash, GENESIS_HASH);
    assert_eq!(entry.index, 0);
    Ok(())
}

#[test]
fn request_headers_carry_rfc_3339_nanosecond_time_and_hex_signature()
-> ExampleResult {
    let identity = rfc_8032_identity()?;
    let timestamp: DateTime<Utc> = FIXED_MOMENT.parse()?;
    let signature = sign_request(&identity, "GET", "/events", timestamp, b"")?;

    let header_values = signature.to_header_values();

    assert_eq!(DEVICE_ID_HEADER, "x-device-id");
    assert_eq!(TIMESTAMP_HEADER, "x-timestamp");
    assert_eq!(SIGNATURE_HEADER, "x-signature");
    assert_eq!(NONCE_HEADER, "x-nonce");
    assert_eq!(header_values.nonce.len(), NONCE_HEX_LENGTH);
    assert_eq!(header_values.device_id, RFC_8032_DEVICE_ID);
    assert_eq!(header_values.timestamp, FIXED_MOMENT_HEADER);
    assert_eq!(header_values.signature.len(), SIGNATURE_HEX_LENGTH);
    Ok(())
}

#[test]
fn sealed_text_is_prefix_then_hex_of_nonce_ciphertext_tag() -> ExampleResult {
    let workspace_key = WorkspaceKey::from_bytes(&[7; KEY_LENGTH])?;
    let text = "deploy to staging";

    let sealed = seal_text(&workspace_key, text)?;

    let sealed_byte_count = NONCE_LENGTH + text.len() + TAG_LENGTH;
    let expected_length =
        SEALED_TEXT_PREFIX.len() + sealed_byte_count * HEX_DIGITS_PER_BYTE;
    assert_eq!(SEALED_TEXT_PREFIX, "sealed-v1:");
    assert!(sealed.starts_with(SEALED_TEXT_PREFIX));
    assert_eq!(sealed.len(), expected_length);
    Ok(())
}

#[test]
fn pairing_session_expires_exactly_five_minutes_after_start() -> ExampleResult
{
    let started_at: DateTime<Utc> = FIXED_MOMENT.parse()?;
    let session = PairingSession::start(started_at)?;

    let expiry = started_at + PAIRING_SESSION_LIFETIME;
    let last_active_moment = expiry - TimeDelta::nanoseconds(1);

    assert_eq!(PAIRING_SESSION_LIFETIME, TimeDelta::minutes(5));
    assert!(!session.is_expired(last_active_moment));
    assert!(session.is_expired(expiry));
    Ok(())
}

#[test]
fn request_exactly_five_minutes_old_is_the_oldest_accepted() -> ExampleResult {
    let identity = rfc_8032_identity()?;
    let signer_key = identity.public_identity().signing_public_key;
    let timestamp: DateTime<Utc> = FIXED_MOMENT.parse()?;
    let signature = sign_request(&identity, "GET", "/events", timestamp, b"")?;

    let oldest_accepted_moment = timestamp + REQUEST_TIMESTAMP_WINDOW;
    let first_rejected_moment =
        oldest_accepted_moment + TimeDelta::nanoseconds(1);

    let at_window_edge = verify_request(
        &signature,
        &signer_key,
        "GET",
        "/events",
        b"",
        oldest_accepted_moment,
    );
    let past_window_edge = verify_request(
        &signature,
        &signer_key,
        "GET",
        "/events",
        b"",
        first_rejected_moment,
    );
    assert_eq!(REQUEST_TIMESTAMP_WINDOW, TimeDelta::minutes(5));
    assert_eq!(at_window_edge, Ok(()));
    assert_eq!(
        past_window_edge,
        Err(SecurityError::RequestTimestampOutsideWindow)
    );
    Ok(())
}
