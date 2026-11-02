use std::fs;

use orchestration_node::identity_store::{
    FileIdentityStore, IdentityStore, KeychainIdentityStore,
};
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

const IDENTITY_FILE_NAME: &str = "device-identity.key";
const LONGEST_ARBITRARY_FILE: usize = 160;
const IDENTITY_STORE_CASES: u32 = 32;

fn temporary_store() -> Result<(TempDir, FileIdentityStore), TestCaseError> {
    let directory = TempDir::new().map_err(fail)?;
    let store =
        FileIdentityStore::new(directory.path().join(IDENTITY_FILE_NAME));
    Ok((directory, store))
}

#[test]
fn keychain_identity_store_can_be_created_without_touching_the_keychain() {
    let store = KeychainIdentityStore::new("orchestration-tests");

    assert!(format!("{store:?}").contains("KeychainIdentityStore"));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(IDENTITY_STORE_CASES))]

    #[test]
    fn test_save_identity_property_load_identity_returns_the_same_identity(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
    ) {
        let (_directory, store) = temporary_store()?;
        let identity =
            DeviceIdentity::from_secret_bytes(&secret).map_err(fail)?;

        store.save_identity(&identity).map_err(fail)?;
        let loaded_identity = store.load_identity().map_err(fail)?;

        let loaded_public =
            loaded_identity.map(|loaded| loaded.public_identity());
        prop_assert_eq!(loaded_public, Some(identity.public_identity()));
    }

    #[test]
    fn test_save_identity_property_only_the_owner_can_read_the_file(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
    ) {
        let (directory, store) = temporary_store()?;
        let identity =
            DeviceIdentity::from_secret_bytes(&secret).map_err(fail)?;

        store.save_identity(&identity).map_err(fail)?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let identity_path = directory.path().join(IDENTITY_FILE_NAME);
            let metadata = fs::metadata(identity_path).map_err(fail)?;
            let group_and_other_bits = metadata.permissions().mode() & 0o077;
            prop_assert_eq!(group_and_other_bits, 0);
        }
    }

    #[test]
    fn test_load_identity_property_arbitrary_file_gives_identity_or_error(
        file_bytes in vec(any::<u8>(), 0..LONGEST_ARBITRARY_FILE),
    ) {
        let (directory, store) = temporary_store()?;
        fs::write(directory.path().join(IDENTITY_FILE_NAME), &file_bytes)
            .map_err(fail)?;

        let loaded_identity = store.load_identity();

        let is_valid_length = file_bytes.len() == IDENTITY_SECRET_LENGTH;
        prop_assert_eq!(loaded_identity.is_ok(), is_valid_length);
    }

    #[test]
    fn test_load_identity_property_missing_file_gives_none(
        file_name in "[a-z]{1,12}",
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let store = FileIdentityStore::new(directory.path().join(file_name));

        prop_assert!(store.load_identity().map_err(fail)?.is_none());
    }
}
