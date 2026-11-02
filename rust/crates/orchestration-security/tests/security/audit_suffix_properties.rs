use chrono::{DateTime, TimeDelta, Utc};
use orchestration_security::audit::{
    AuditEntry, SignerKeys, append_entry, verify_chain, verify_chain_suffix,
};
use orchestration_security::error::{AuditChainProblem, SecurityError};
use orchestration_security::identity::DeviceIdentity;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::{moment_strategy, secret_strategy, short_text_strategy};

const LONGEST_TEST_CHAIN: usize = 8;

fn build_chain(
    author: &DeviceIdentity,
    events: &[String],
    started_at: DateTime<Utc>,
) -> Vec<AuditEntry> {
    let mut chain = Vec::new();
    for (offset, event) in (0_i64..).zip(events) {
        let at = started_at + TimeDelta::seconds(offset);
        let entry = append_entry(&chain, author, event.clone(), None, at);
        chain.push(entry);
    }
    chain
}

fn keys_of(author: &DeviceIdentity) -> SignerKeys {
    let public_identity = author.public_identity();
    SignerKeys::from([(
        public_identity.device_id,
        public_identity.signing_public_key,
    )])
}

proptest! {
    #[test]
    fn test_verify_chain_suffix_property_agrees_with_the_whole_chain(
        secret in secret_strategy(),
        events in vec(short_text_strategy(), 1..LONGEST_TEST_CHAIN),
        verified_length in 0..LONGEST_TEST_CHAIN,
        started_at in moment_strategy(),
    ) {
        let author = DeviceIdentity::from_secret_bytes(&secret)?;
        let chain = build_chain(&author, &events, started_at);
        let verified_length = verified_length.min(chain.len());
        let signer_keys = keys_of(&author);

        let suffix =
            verify_chain_suffix(&chain, verified_length, &signer_keys);
        let whole = verify_chain(&chain, &signer_keys);

        prop_assert_eq!(suffix, whole);
    }

    #[test]
    fn test_verify_chain_suffix_property_refuses_a_changed_new_entry(
        secret in secret_strategy(),
        events in vec(short_text_strategy(), 2..LONGEST_TEST_CHAIN),
        started_at in moment_strategy(),
    ) {
        let author = DeviceIdentity::from_secret_bytes(&secret)?;
        let mut chain = build_chain(&author, &events, started_at);
        let last_index = chain.len() - 1;
        chain[last_index].event.push('!');

        let checked =
            verify_chain_suffix(&chain, last_index, &keys_of(&author));

        prop_assert_eq!(
            checked,
            Err(SecurityError::AuditChainBroken {
                index: last_index,
                problem: AuditChainProblem::WrongHash,
            })
        );
    }

    #[test]
    fn test_verify_chain_suffix_property_refuses_a_length_past_the_end(
        secret in secret_strategy(),
        events in vec(short_text_strategy(), 0..LONGEST_TEST_CHAIN),
        extra in 1..LONGEST_TEST_CHAIN,
        started_at in moment_strategy(),
    ) {
        let author = DeviceIdentity::from_secret_bytes(&secret)?;
        let chain = build_chain(&author, &events, started_at);
        let signer_keys = keys_of(&author);

        let checked =
            verify_chain_suffix(&chain, chain.len() + extra, &signer_keys);

        prop_assert_eq!(
            checked,
            Err(SecurityError::AuditChainBroken {
                index: chain.len(),
                problem: AuditChainProblem::WrongIndex,
            })
        );
    }
}
