use std::fs;
use std::sync::Arc;

use orchestration_node::agent_credentials::{
    API_KEY_VARIABLE, AgentCredential, AgentCredentialKind, AgentCredentials,
    LONG_LIVED_TOKEN_VARIABLE,
};
use orchestration_node::identity_store::{
    EncryptedFileIdentityStore, FileIdentityStore, IdentityStore,
};
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

const IDENTITY_FILE_NAME: &str = "device-identity.key";
const SEALED_IDENTITY_FILE_NAME: &str = "device-identity.sealed";
const CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
const SEALED_CREDENTIAL_FILE_NAME: &str = "agent-credential.sealed";
const STORE_KEY: [u8; 32] = [7; 32];
const CREDENTIAL_CASES: u32 = 32;

fn any_kind() -> impl Strategy<Value = AgentCredentialKind> {
    prop_oneof![
        Just(AgentCredentialKind::LongLivedToken),
        Just(AgentCredentialKind::ApiKey),
    ]
}

fn any_secret() -> impl Strategy<Value = String> {
    "sk-ant-[A-Za-z0-9_-]{8,80}"
}

fn any_credential() -> impl Strategy<Value = AgentCredential> {
    (any_kind(), any_secret())
        .prop_filter_map("the secret is valid", |(kind, secret)| {
            AgentCredential::new(kind, &secret).ok()
        })
}

fn open_file_store(directory: &TempDir) -> Arc<dyn IdentityStore> {
    let identity_path = directory.path().join(IDENTITY_FILE_NAME);
    Arc::new(FileIdentityStore::new(identity_path))
}

fn open_sealed_store(
    directory: &TempDir,
) -> Result<Arc<dyn IdentityStore>, TestCaseError> {
    let identity_path = directory.path().join(SEALED_IDENTITY_FILE_NAME);
    let store = EncryptedFileIdentityStore::new(identity_path, &STORE_KEY)
        .map_err(fail)?;
    Ok(Arc::new(store))
}

fn contains_bytes(haystack: &[u8], needle: &[u8]) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CREDENTIAL_CASES))]

    #[test]
    fn test_new_property_a_valid_secret_is_kept_without_its_padding(
        kind in any_kind(),
        secret in any_secret(),
        padding_before in "[ \t\r\n]{0,3}",
        padding_after in "[ \t\r\n]{0,3}",
    ) {
        let padded = format!("{padding_before}{secret}{padding_after}");

        let credential =
            AgentCredential::new(kind, &padded).map_err(fail)?;

        prop_assert_eq!(credential.secret(), secret.as_str());
        prop_assert_eq!(credential.kind(), kind);
    }

    #[test]
    fn test_new_property_inner_spaces_or_controls_are_refused(
        kind in any_kind(),
        start in "[a-z]{1,10}",
        breaker in "[ \t\r\n\u{0}\u{7}\u{1b}]",
        end in "[a-z]{1,10}",
    ) {
        let secret = format!("{start}{breaker}{end}");

        prop_assert!(AgentCredential::new(kind, &secret).is_err());
    }

    #[test]
    fn test_new_property_blank_secrets_are_refused(
        kind in any_kind(),
        blank in "[ \t\r\n]{0,6}",
    ) {
        prop_assert!(AgentCredential::new(kind, &blank).is_err());
    }

    #[test]
    fn test_environment_variable_property_follows_the_kind(
        credential in any_credential(),
    ) {
        let expected = match credential.kind() {
            AgentCredentialKind::LongLivedToken => LONG_LIVED_TOKEN_VARIABLE,
            AgentCredentialKind::ApiKey => API_KEY_VARIABLE,
        };

        prop_assert_eq!(credential.environment_variable(), expected);
    }

    #[test]
    fn test_debug_property_never_shows_the_secret(
        credential in any_credential(),
    ) {
        let shown = format!("{credential:?}");

        prop_assert!(!shown.contains(credential.secret()));
    }

    #[test]
    fn test_keep_property_a_kept_credential_survives_reopening(
        credential in any_credential(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let credentials =
            AgentCredentials::open(open_file_store(&directory))
                .map_err(fail)?;

        credentials.keep(credential.clone()).map_err(fail)?;
        let reopened = AgentCredentials::open(open_file_store(&directory))
            .map_err(fail)?;

        prop_assert_eq!(credentials.current(), Some(credential.clone()));
        prop_assert_eq!(reopened.current(), Some(credential));
    }

    #[test]
    fn test_forget_property_a_forgotten_credential_stays_gone(
        credential in any_credential(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let credentials =
            AgentCredentials::open(open_file_store(&directory))
                .map_err(fail)?;
        credentials.keep(credential).map_err(fail)?;

        credentials.forget().map_err(fail)?;
        let reopened = AgentCredentials::open(open_file_store(&directory))
            .map_err(fail)?;

        prop_assert_eq!(credentials.current(), None);
        prop_assert_eq!(reopened.current(), None);
    }

    #[test]
    fn test_keep_property_only_the_owner_can_read_the_file(
        credential in any_credential(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let credentials =
            AgentCredentials::open(open_file_store(&directory))
                .map_err(fail)?;

        credentials.keep(credential).map_err(fail)?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let path = directory.path().join(CREDENTIAL_FILE_NAME);
            let metadata = fs::metadata(path).map_err(fail)?;
            let group_and_other_bits = metadata.permissions().mode() & 0o077;
            prop_assert_eq!(group_and_other_bits, 0);
        }
    }

    #[test]
    fn test_keep_property_a_sealed_store_hides_the_secret(
        credential in any_credential(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let credentials =
            AgentCredentials::open(open_sealed_store(&directory)?)
                .map_err(fail)?;

        credentials.keep(credential.clone()).map_err(fail)?;
        let reopened =
            AgentCredentials::open(open_sealed_store(&directory)?)
                .map_err(fail)?;

        let sealed_path = directory.path().join(SEALED_CREDENTIAL_FILE_NAME);
        let sealed_bytes = fs::read(sealed_path).map_err(fail)?;
        let secret_bytes = credential.secret().as_bytes();
        prop_assert!(!contains_bytes(&sealed_bytes, secret_bytes));
        prop_assert_eq!(reopened.current(), Some(credential));
    }

    #[test]
    fn test_open_property_a_damaged_credential_file_is_refused(
        file_bytes in proptest::collection::vec(any::<u8>(), 0..120),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let path = directory.path().join(CREDENTIAL_FILE_NAME);
        fs::write(path, &file_bytes).map_err(fail)?;

        let opened = AgentCredentials::open(open_file_store(&directory));

        prop_assert!(opened.is_err());
    }
}

#[test]
fn a_store_without_a_credential_opens_empty() {
    let Ok(directory) = TempDir::new() else {
        panic!("a temporary folder is made");
    };

    let opened = AgentCredentials::open(open_file_store(&directory));

    let Ok(credentials) = opened else {
        panic!("the credentials open: {opened:?}");
    };
    assert_eq!(credentials.current(), None);
}
