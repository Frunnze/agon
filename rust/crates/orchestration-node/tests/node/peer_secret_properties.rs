use std::fs;

use orchestration_node::identity_store::{FileIdentityStore, IdentityStore};
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

const IDENTITY_FILE_NAME: &str = "device-identity.key";
const PEER_SECRET_FILE_NAME: &str = "peer-secret.key";
const PEER_SECRET_LENGTH: usize = 32;

fn temporary_store() -> Result<(TempDir, FileIdentityStore), TestCaseError> {
    let directory = TempDir::new().map_err(fail)?;
    let store =
        FileIdentityStore::new(directory.path().join(IDENTITY_FILE_NAME));
    Ok((directory, store))
}

#[test]
fn a_new_store_has_no_peer_secret() {
    let Ok((_directory, store)) = temporary_store() else {
        panic!("the store opens");
    };

    let loaded = store.load_peer_secret();

    assert!(matches!(loaded, Ok(None)), "{loaded:?}");
}

proptest! {
    #[test]
    fn test_save_peer_secret_property_load_returns_the_same_secret(
        secret in any::<[u8; PEER_SECRET_LENGTH]>(),
    ) {
        let (directory, store) = temporary_store()?;

        store.save_peer_secret(&secret).map_err(fail)?;
        let loaded = store.load_peer_secret().map_err(fail)?;

        prop_assert_eq!(loaded.map(|loaded| *loaded), Some(secret));
        let identity_path = directory.path().join(IDENTITY_FILE_NAME);
        prop_assert!(!identity_path.exists());
    }

    #[test]
    fn test_load_peer_secret_property_wrong_lengths_are_damaged(
        stored in proptest::collection::vec(any::<u8>(), 0..64),
    ) {
        prop_assume!(stored.len() != PEER_SECRET_LENGTH);
        let (directory, store) = temporary_store()?;
        let secret_path = directory.path().join(PEER_SECRET_FILE_NAME);
        fs::write(secret_path, &stored).map_err(fail)?;

        let loaded = store.load_peer_secret();

        prop_assert!(loaded.is_err());
    }
}
