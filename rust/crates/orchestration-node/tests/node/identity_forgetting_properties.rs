use std::fs;
use std::path::Path;

use orchestration_node::identity_store::{
    EncryptedFileIdentityStore, FileIdentityStore, IdentityStore,
};
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

const PLAIN_IDENTITY_FILE_NAME: &str = "device-identity.key";
const SEALED_IDENTITY_FILE_NAME: &str = "device-identity.sealed";
const BLOCKING_FILE_NAME: &str = "keeps-the-directory-full";
const STORE_KEY_LENGTH: usize = 32;
const PEER_SECRET_LENGTH: usize = 32;
const MOST_REPEATED_FORGETS: usize = 3;
const FORGETTING_CASES: u32 = 24;

type StoreKey = [u8; STORE_KEY_LENGTH];
type PeerSecretBytes = [u8; PEER_SECRET_LENGTH];

fn open_plain_store(directory: &TempDir) -> FileIdentityStore {
    FileIdentityStore::new(directory.path().join(PLAIN_IDENTITY_FILE_NAME))
}

fn open_sealed_store(
    directory: &TempDir,
    key: &StoreKey,
) -> Result<EncryptedFileIdentityStore, TestCaseError> {
    let identity_path = directory.path().join(SEALED_IDENTITY_FILE_NAME);
    EncryptedFileIdentityStore::new(identity_path, key).map_err(fail)
}

fn fill_store(
    store: &dyn IdentityStore,
    secret: &[u8],
    peer_secret: &PeerSecretBytes,
) -> Result<(), TestCaseError> {
    let identity = DeviceIdentity::from_secret_bytes(secret).map_err(fail)?;
    store.save_identity(&identity).map_err(fail)?;
    store.save_peer_secret(peer_secret).map_err(fail)
}

fn forget_repeatedly(
    store: &dyn IdentityStore,
    forget_count: usize,
) -> Result<(), TestCaseError> {
    for _ in 0..forget_count {
        store.forget_identity().map_err(fail)?;
        store.forget_peer_secret().map_err(fail)?;
    }
    Ok(())
}

fn is_empty_store(store: &dyn IdentityStore) -> Result<bool, TestCaseError> {
    let identity = store.load_identity().map_err(fail)?;
    let peer_secret = store.load_peer_secret().map_err(fail)?;
    Ok(identity.is_none() && peer_secret.is_none())
}

fn count_files(directory: &TempDir) -> Result<usize, TestCaseError> {
    let entries = fs::read_dir(directory.path()).map_err(fail)?;
    Ok(entries.count())
}

fn block_with_directory(path: &Path) -> Result<(), TestCaseError> {
    fs::create_dir(path).map_err(fail)?;
    fs::write(path.join(BLOCKING_FILE_NAME), BLOCKING_FILE_NAME).map_err(fail)
}

#[test]
fn forgetting_an_empty_store_succeeds() {
    let Ok(directory) = TempDir::new() else {
        panic!("the directory is created");
    };
    let store = open_plain_store(&directory);

    let identity_forgotten = store.forget_identity();
    let peer_secret_forgotten = store.forget_peer_secret();

    assert!(identity_forgotten.is_ok(), "{identity_forgotten:?}");
    assert!(peer_secret_forgotten.is_ok(), "{peer_secret_forgotten:?}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FORGETTING_CASES))]

    #[test]
    fn test_forget_identity_property_a_file_store_keeps_no_file(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        peer_secret in any::<PeerSecretBytes>(),
        forget_count in 1..=MOST_REPEATED_FORGETS,
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_plain_store(&directory);
        fill_store(&store, &secret, &peer_secret)?;

        forget_repeatedly(&store, forget_count)?;

        prop_assert!(is_empty_store(&store)?);
        prop_assert_eq!(count_files(&directory)?, 0);
    }

    #[test]
    fn test_forget_identity_property_a_sealed_store_keeps_no_file(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        peer_secret in any::<PeerSecretBytes>(),
        key in any::<StoreKey>(),
        forget_count in 1..=MOST_REPEATED_FORGETS,
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_sealed_store(&directory, &key)?;
        fill_store(&store, &secret, &peer_secret)?;

        forget_repeatedly(&store, forget_count)?;

        prop_assert!(is_empty_store(&store)?);
        prop_assert_eq!(count_files(&directory)?, 0);
    }

    #[test]
    fn test_forget_identity_property_the_peer_secret_stays(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        peer_secret in any::<PeerSecretBytes>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_plain_store(&directory);
        fill_store(&store, &secret, &peer_secret)?;

        store.forget_identity().map_err(fail)?;

        prop_assert!(store.load_identity().map_err(fail)?.is_none());
        let kept = store.load_peer_secret().map_err(fail)?;
        prop_assert_eq!(kept.map(|kept| *kept), Some(peer_secret));
    }

    #[test]
    fn test_forget_peer_secret_property_the_identity_stays(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        peer_secret in any::<PeerSecretBytes>(),
        key in any::<StoreKey>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_sealed_store(&directory, &key)?;
        fill_store(&store, &secret, &peer_secret)?;

        store.forget_peer_secret().map_err(fail)?;

        prop_assert!(store.load_peer_secret().map_err(fail)?.is_none());
        let kept = store.load_identity().map_err(fail)?;
        let expected = DeviceIdentity::from_secret_bytes(&secret)
            .map_err(fail)?
            .public_identity();
        prop_assert_eq!(
            kept.map(|kept| kept.public_identity()),
            Some(expected)
        );
    }

    #[test]
    fn test_forget_identity_property_a_blocked_identity_gives_an_error(
        peer_secret in any::<PeerSecretBytes>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = open_plain_store(&directory);
        store.save_peer_secret(&peer_secret).map_err(fail)?;
        let identity_path = directory.path().join(PLAIN_IDENTITY_FILE_NAME);
        block_with_directory(&identity_path)?;

        let forgotten = store.forget_identity();

        prop_assert!(forgotten.is_err());
        prop_assert!(identity_path.exists());
        let kept = store.load_peer_secret().map_err(fail)?;
        prop_assert_eq!(kept.map(|kept| *kept), Some(peer_secret));
    }
}
