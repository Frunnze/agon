use std::sync::Arc;
use std::thread;

use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentials,
};
use proptest::prelude::*;

use crate::credential_folders::{create_node_folder, open_credentials};
use crate::secret_rules::any_credential;
use crate::support::test_device::{describe, fail};

const LOCK_CASES: u32 = 12;
const MAXIMUM_WRITERS: usize = 5;
const READS_PER_READER: usize = 20;

#[derive(Clone, Debug)]
enum CredentialChange {
    Keep(AgentCredential),
    Forget,
}

fn any_change() -> impl Strategy<Value = CredentialChange> {
    prop_oneof![
        3 => any_credential().prop_map(CredentialChange::Keep),
        1 => Just(CredentialChange::Forget),
    ]
}

fn apply_change(
    credentials: &AgentCredentials,
    change: CredentialChange,
) -> Result<(), String> {
    match change {
        CredentialChange::Keep(credential) => {
            credentials.keep(credential).map_err(describe)
        }
        CredentialChange::Forget => credentials.forget().map_err(describe),
    }
}

fn apply_changes_at_once(
    credentials: &Arc<AgentCredentials>,
    changes: &[CredentialChange],
) -> Result<(), TestCaseError> {
    let mut writers = Vec::new();
    for change in changes {
        let shared = Arc::clone(credentials);
        let change = change.clone();
        writers.push(thread::spawn(move || apply_change(&shared, change)));
    }
    for writer in writers {
        let applied = writer
            .join()
            .map_err(|_| TestCaseError::fail("a writer panicked"))?;
        applied.map_err(fail)?;
    }
    Ok(())
}

fn any_changes() -> impl Strategy<Value = Vec<CredentialChange>> {
    proptest::collection::vec(any_change(), 1..MAXIMUM_WRITERS)
}

fn read_repeatedly(
    credentials: &AgentCredentials,
) -> Vec<Option<AgentCredential>> {
    let mut readings = Vec::new();
    for _ in 0..READS_PER_READER {
        readings.push(credentials.current());
    }
    readings
}

fn is_possible_reading(
    reading: Option<&AgentCredential>,
    changes: &[CredentialChange],
) -> bool {
    let Some(reading) = reading else {
        return true;
    };
    for change in changes {
        if let CredentialChange::Keep(credential) = change
            && credential == reading
        {
            return true;
        }
    }
    false
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOCK_CASES))]

    #[test]
    fn test_agent_credentials_current_property_agrees_with_the_disk(
        changes in any_changes(),
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;

        for change in changes {
            apply_change(&credentials, change).map_err(fail)?;

            let reopened = open_credentials(&folder.path)?;
            prop_assert_eq!(credentials.current(), reopened.current());
        }
    }

    #[test]
    fn test_lock_current_property_memory_and_disk_agree_after_racing(
        changes in any_changes(),
    ) {
        let folder = create_node_folder()?;
        let credentials = Arc::new(open_credentials(&folder.path)?);

        apply_changes_at_once(&credentials, &changes)?;

        let reopened = open_credentials(&folder.path)?;
        prop_assert_eq!(credentials.current(), reopened.current());
    }

    #[test]
    fn test_lock_current_property_racing_keeps_one_of_the_credentials(
        changes in any_changes(),
    ) {
        let folder = create_node_folder()?;
        let credentials = Arc::new(open_credentials(&folder.path)?);

        apply_changes_at_once(&credentials, &changes)?;

        let current = credentials.current();
        prop_assert!(is_possible_reading(current.as_ref(), &changes));
    }

    #[test]
    fn test_lock_current_property_readers_never_see_a_stranger(
        changes in any_changes(),
    ) {
        let folder = create_node_folder()?;
        let credentials = Arc::new(open_credentials(&folder.path)?);
        let reading_credentials = Arc::clone(&credentials);
        let reader =
            thread::spawn(move || read_repeatedly(&reading_credentials));

        apply_changes_at_once(&credentials, &changes)?;
        let readings = reader
            .join()
            .map_err(|_| TestCaseError::fail("the reader panicked"))?;

        for reading in readings {
            prop_assert!(is_possible_reading(reading.as_ref(), &changes));
        }
    }
}
