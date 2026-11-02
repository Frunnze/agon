use chrono::{DateTime, Utc};
use orchestration_security::audit::{
    AuditEntry, SignerKeys, append_entry, verify_chain,
};
use orchestration_security::identity::DeviceIdentity;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::{moment_strategy, secret_strategy};

const MOST_ENTRIES: usize = 6;

type EventAndDetail = (String, Option<String>);

fn event_strategy() -> impl Strategy<Value = EventAndDetail> {
    ("[a-z ]{1,24}", proptest::option::of("[a-z0-9 #/.-]{0,24}"))
}

fn build_detailed_chain(
    author: &DeviceIdentity,
    events: &[EventAndDetail],
    at: DateTime<Utc>,
) -> Vec<AuditEntry> {
    let mut chain = Vec::new();
    for (event, detail) in events {
        let entry =
            append_entry(&chain, author, event.clone(), detail.clone(), at);
        chain.push(entry);
    }
    chain
}

fn keys_of(author: &DeviceIdentity) -> SignerKeys {
    let public_identity = author.public_identity();
    SignerKeys::from([(
        author.device_id(),
        public_identity.signing_public_key,
    )])
}

proptest! {
    #[test]
    fn test_append_entry_property_keeps_each_detail_and_verifies(
        secret in secret_strategy(),
        events in vec(event_strategy(), 1..MOST_ENTRIES),
        at in moment_strategy(),
    ) {
        let author = DeviceIdentity::from_secret_bytes(&secret)?;

        let chain = build_detailed_chain(&author, &events, at);

        for (entry, (_event, detail)) in chain.iter().zip(&events) {
            prop_assert_eq!(&entry.detail, detail);
        }
        prop_assert!(verify_chain(&chain, &keys_of(&author)).is_ok());
    }

    #[test]
    fn test_verify_chain_property_detects_a_changed_detail(
        secret in secret_strategy(),
        events in vec(event_strategy(), 1..MOST_ENTRIES),
        position in any::<prop::sample::Index>(),
        forged_detail in "[a-z]{1,12}",
        at in moment_strategy(),
    ) {
        let author = DeviceIdentity::from_secret_bytes(&secret)?;
        let mut chain = build_detailed_chain(&author, &events, at);
        let changed = position.index(chain.len());
        prop_assume!(chain[changed].detail.as_deref() != Some(&forged_detail));

        chain[changed].detail = Some(forged_detail);

        prop_assert!(verify_chain(&chain, &keys_of(&author)).is_err());
    }
}
