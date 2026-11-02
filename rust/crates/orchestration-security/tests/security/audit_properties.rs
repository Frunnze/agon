use std::collections::BTreeMap;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_security::audit::{
    AuditEntry, GENESIS_HASH, append_entry, verify_chain,
};
use orchestration_security::error::{AuditChainProblem, SecurityError};
use orchestration_security::identity::DeviceIdentity;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::{
    distinct_secrets_strategy, flip_bit, moment_strategy, short_text_strategy,
};

const LONGEST_TEST_CHAIN: usize = 8;

type SignerKeys = BTreeMap<DeviceId, Vec<u8>>;

fn events_strategy(shortest: usize) -> impl Strategy<Value = Vec<String>> {
    vec(short_text_strategy(), shortest..LONGEST_TEST_CHAIN)
}

fn build_chain(
    authors: &[DeviceIdentity],
    events: &[String],
    started_at: DateTime<Utc>,
) -> Result<Vec<AuditEntry>, TestCaseError> {
    let mut chain = Vec::new();
    for (position, event) in events.iter().enumerate() {
        let author = &authors[position % authors.len()];
        let offset_seconds = i64::try_from(position)
            .map_err(|_| TestCaseError::fail("position exceeds i64"))?;
        let at = started_at + TimeDelta::seconds(offset_seconds);
        let entry = append_entry(&chain, author, event.clone(), None, at);
        chain.push(entry);
    }
    Ok(chain)
}

fn signer_keys_for(authors: &[DeviceIdentity]) -> SignerKeys {
    let mut signer_keys = SignerKeys::new();
    for author in authors {
        let public_identity = author.public_identity();
        signer_keys.insert(
            public_identity.device_id,
            public_identity.signing_public_key,
        );
    }
    signer_keys
}

fn two_authors(
    (first_secret, second_secret): &(Vec<u8>, Vec<u8>),
) -> Result<Vec<DeviceIdentity>, TestCaseError> {
    Ok(vec![
        DeviceIdentity::from_secret_bytes(first_secret)?,
        DeviceIdentity::from_secret_bytes(second_secret)?,
    ])
}

fn broken_at(index: usize, problem: AuditChainProblem) -> SecurityError {
    SecurityError::AuditChainBroken { index, problem }
}

proptest! {
    #[test]
    fn test_append_entry_property_links_each_entry_to_previous_hash(
        secrets in distinct_secrets_strategy(),
        events in events_strategy(1),
        started_at in moment_strategy(),
    ) {
        let authors = two_authors(&secrets)?;

        let chain = build_chain(&authors, &events, started_at)?;

        let mut expected_previous_hash = GENESIS_HASH.to_owned();
        for (position, entry) in chain.iter().enumerate() {
            prop_assert_eq!(entry.index, position);
            prop_assert_eq!(&entry.event, &events[position]);
            prop_assert_eq!(&entry.previous_hash, &expected_previous_hash);
            prop_assert_ne!(&entry.hash, &entry.previous_hash);
            expected_previous_hash = entry.hash.clone();
        }
    }

    #[test]
    fn test_verify_chain_property_accepts_untampered_chain(
        secrets in distinct_secrets_strategy(),
        events in events_strategy(0),
        started_at in moment_strategy(),
    ) {
        let authors = two_authors(&secrets)?;
        let chain = build_chain(&authors, &events, started_at)?;

        let summary = verify_chain(&chain, &signer_keys_for(&authors))?;

        let expected_head = chain
            .last()
            .map_or(GENESIS_HASH.to_owned(), |entry| entry.hash.clone());
        prop_assert_eq!(summary.entry_count, events.len());
        prop_assert_eq!(summary.head_hash, expected_head);
    }

    #[test]
    fn test_verify_chain_property_changed_event_fails_at_its_index(
        secrets in distinct_secrets_strategy(),
        events in events_strategy(1),
        started_at in moment_strategy(),
        position in any::<usize>(),
    ) {
        let authors = two_authors(&secrets)?;
        let mut chain = build_chain(&authors, &events, started_at)?;
        let tampered_index = position % chain.len();
        chain[tampered_index].event.push('!');

        let verification = verify_chain(&chain, &signer_keys_for(&authors));

        let expected = broken_at(tampered_index, AuditChainProblem::WrongHash);
        prop_assert_eq!(verification, Err(expected));
    }

    #[test]
    fn test_verify_chain_property_flipped_signature_fails_at_its_index(
        secrets in distinct_secrets_strategy(),
        events in events_strategy(1),
        started_at in moment_strategy(),
        position in any::<usize>(),
        bit in any::<u8>(),
    ) {
        let authors = two_authors(&secrets)?;
        let mut chain = build_chain(&authors, &events, started_at)?;
        let tampered_index = position % chain.len();
        let tampered_entry = &mut chain[tampered_index];
        tampered_entry.signature =
            flip_bit(&tampered_entry.signature, position, bit);

        let verification = verify_chain(&chain, &signer_keys_for(&authors));

        let expected =
            broken_at(tampered_index, AuditChainProblem::InvalidSignature);
        prop_assert_eq!(verification, Err(expected));
    }

    #[test]
    fn test_verify_chain_property_removed_entry_fails_at_its_index(
        secrets in distinct_secrets_strategy(),
        events in events_strategy(2),
        started_at in moment_strategy(),
        position in any::<usize>(),
    ) {
        let authors = two_authors(&secrets)?;
        let mut chain = build_chain(&authors, &events, started_at)?;
        let removed_index = position % (chain.len() - 1);
        chain.remove(removed_index);

        let verification = verify_chain(&chain, &signer_keys_for(&authors));

        let expected = broken_at(removed_index, AuditChainProblem::WrongIndex);
        prop_assert_eq!(verification, Err(expected));
    }

    #[test]
    fn test_verify_chain_property_rehashed_entry_breaks_next_link(
        secrets in distinct_secrets_strategy(),
        events in events_strategy(2),
        started_at in moment_strategy(),
        position in any::<usize>(),
    ) {
        let authors = two_authors(&secrets)?;
        let mut chain = build_chain(&authors, &events, started_at)?;
        let rewritten_index = position % (chain.len() - 1);
        let rewritten_author = &authors[rewritten_index % authors.len()];
        let earlier_entries = &chain[..rewritten_index];
        let rewritten_entry = append_entry(
            earlier_entries,
            rewritten_author,
            format!("{}!", chain[rewritten_index].event),
            None,
            chain[rewritten_index].at,
        );
        chain[rewritten_index] = rewritten_entry;

        let verification = verify_chain(&chain, &signer_keys_for(&authors));

        let expected = broken_at(
            rewritten_index + 1,
            AuditChainProblem::WrongPreviousHash,
        );
        prop_assert_eq!(verification, Err(expected));
    }

    #[test]
    fn test_verify_chain_property_unknown_signer_fails_at_its_first_entry(
        secrets in distinct_secrets_strategy(),
        events in events_strategy(2),
        started_at in moment_strategy(),
    ) {
        let authors = two_authors(&secrets)?;
        let chain = build_chain(&authors, &events, started_at)?;
        let known_authors = &authors[..1];

        let verification =
            verify_chain(&chain, &signer_keys_for(known_authors));

        let expected = broken_at(1, AuditChainProblem::UnknownSigner);
        prop_assert_eq!(verification, Err(expected));
    }
}
