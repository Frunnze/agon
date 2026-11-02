use std::sync::{Arc, LazyLock};

use keyring_core::{CredentialStore, Error as KeychainError};

use super::IdentityStoreError;

static PLATFORM_STORE: LazyLock<Result<(), String>> =
    LazyLock::new(install_platform_store);

pub(super) fn ensure_platform_store() -> Result<(), IdentityStoreError> {
    match &*PLATFORM_STORE {
        Ok(()) => Ok(()),
        Err(problem) => Err(IdentityStoreError::Keychain(problem.clone())),
    }
}

fn install_platform_store() -> Result<(), String> {
    let store = open_platform_store().map_err(|error| error.to_string())?;
    keyring_core::set_default_store(store);
    Ok(())
}

#[cfg(target_os = "macos")]
fn open_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        apple_native_keyring_store::keychain::Store::new()?;
    Ok(store)
}

#[cfg(target_os = "ios")]
fn open_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        apple_native_keyring_store::protected::Store::new()?;
    Ok(store)
}

#[cfg(target_os = "windows")]
fn open_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        windows_native_keyring_store::Store::new()?;
    Ok(store)
}

#[cfg(target_os = "linux")]
fn open_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        zbus_secret_service_keyring_store::Store::new()?;
    Ok(store)
}

#[cfg(not(any(
    target_os = "macos",
    target_os = "ios",
    target_os = "windows",
    target_os = "linux"
)))]
fn open_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    Err(KeychainError::NotSupportedByStore(
        "this platform has no keychain; use the encrypted_file store".into(),
    ))
}
