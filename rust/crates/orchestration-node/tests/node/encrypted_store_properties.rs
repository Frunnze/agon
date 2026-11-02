use std::fs;

use orchestration_node::identity_store::{
    EncryptedFileIdentityStore, IdentityStore, KeychainIdentityStore,
};
use orchestration_node::node_runtime::NodeRuntime;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;
use tempfile::TempDir;

use crate::support::test_device::fail;

const IDENTITY_FILE_NAME: &str = "device-identity.sealed";
const STORE_KEY_LENGTH: usize = 32;
const PEER_SECRET_LENGTH: usize = 32;

type StoreKey = [u8; STORE_KEY_LENGTH];

fn open_store(
    directory: &TempDir,
    key: &StoreKey,
) -> Result<EncryptedFileIdentityStore, TestCaseError> {
    let identity_path = directory.path().join(IDENTITY_FILE_NAME);
    EncryptedFileIdentityStore::new(identity_path, key).map_err(fail)
}

fn identity_from(secret: &[u8]) -> Result<DeviceIdentity, TestCaseError> {
    DeviceIdentity::from_secret_bytes(secret).map_err(fail)
}

fn contains_bytes(haystack: &[u8], needle: &[u8]) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}

fn distinct_keys() -> impl Strategy<Value = (StoreKey, StoreKey)> {
    (any::<StoreKey>(), any::<StoreKey>())
        .prop_filter("the keys differ", |(first, second)| first != second)
}

#[test]
fn the_keychain_resolves_to_a_real_store_on_this_host() {
    let store = KeychainIdentityStore::new("orchestration-tests");

    let availability = store.ensure_available();

    if cfg!(target_os = "linux") && availability.is_err() {
        return;
    }
    assert!(availability.is_ok(), "{availability:?}");
}

#[test]
fn a_node_starts_with_an_encrypted_file_store_and_refuses_a_bad_key() {
    let Ok(directory) = TempDir::new() else {
        panic!("the data directory is created");
    };
    let configuration = |key: &str| {
        json!({
            "data_directory": directory.path(),
            "identity_store": { "encrypted_file": { "key": key } },
            "runner": "off",
            "peer_relay": "disabled",
        })
        .to_string()
    };
    let good_key = "11".repeat(STORE_KEY_LENGTH);

    let started = NodeRuntime::start(&configuration(&good_key));
    let short_key = NodeRuntime::start(&configuration("abcd"));
    let not_hex = NodeRuntime::start(&configuration(&"zz".repeat(32)));

    assert!(started.is_ok(), "{:?}", started.err());
    assert!(short_key.is_err());
    assert!(not_hex.is_err());
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(32))]

    #[test]
    fn test_save_identity_property_encrypted_file_round_trips(
        key in any::<StoreKey>(),
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        peer_secret in any::<[u8; PEER_SECRET_LENGTH]>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_store(&directory, &key)?;
        let identity = identity_from(&secret)?;

        store.save_identity(&identity).map_err(fail)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;
        let reopened = open_store(&directory, &key)?;

        let loaded = reopened.load_identity().map_err(fail)?;
        let loaded_public = loaded.map(|loaded| loaded.public_identity());
        prop_assert_eq!(loaded_public, Some(identity.public_identity()));
        let loaded_peer = reopened.load_peer_secret().map_err(fail)?;
        prop_assert_eq!(loaded_peer.map(|loaded| *loaded), Some(peer_secret));
        let stored_bytes = fs::read(directory.path().join(IDENTITY_FILE_NAME))
            .map_err(fail)?;
        prop_assert!(!contains_bytes(&stored_bytes, &secret));
    }

    #[test]
    fn test_load_identity_property_a_wrong_key_is_rejected(
        (key, other_key) in distinct_keys(),
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        peer_secret in any::<[u8; PEER_SECRET_LENGTH]>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_store(&directory, &key)?;
        let identity = identity_from(&secret)?;
        store.save_identity(&identity).map_err(fail)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;

        let wrong_store = open_store(&directory, &other_key)?;

        prop_assert!(wrong_store.load_identity().is_err());
        prop_assert!(wrong_store.load_peer_secret().is_err());
    }

    #[test]
    fn test_load_identity_property_any_tampered_byte_is_rejected(
        key in any::<StoreKey>(),
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        position in any::<prop::sample::Index>(),
        flip in 1_u8..=255,
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_store(&directory, &key)?;
        let identity = identity_from(&secret)?;
        store.save_identity(&identity).map_err(fail)?;
        let identity_path = directory.path().join(IDENTITY_FILE_NAME);
        let mut stored_bytes = fs::read(&identity_path).map_err(fail)?;

        let tampered = position.index(stored_bytes.len());
        stored_bytes[tampered] ^= flip;
        fs::write(&identity_path, &stored_bytes).map_err(fail)?;

        prop_assert!(store.load_identity().is_err());
    }
}

#[cfg(unix)]
#[test]
fn the_encrypted_file_is_readable_only_by_its_owner() {
    use std::os::unix::fs::PermissionsExt;

    let Ok(directory) = TempDir::new() else {
        panic!("the data directory is created");
    };
    let key = [3_u8; STORE_KEY_LENGTH];
    let Ok(store) = open_store(&directory, &key) else {
        panic!("the store opens");
    };
    let Ok(identity) = DeviceIdentity::generate() else {
        panic!("an identity is generated");
    };

    let saved = store.save_identity(&identity);

    assert!(saved.is_ok(), "{saved:?}");
    let identity_path = directory.path().join(IDENTITY_FILE_NAME);
    let mode = fs::metadata(identity_path)
        .map(|meta| meta.permissions().mode() & 0o777)
        .ok();
    assert_eq!(mode, Some(0o600));
}
