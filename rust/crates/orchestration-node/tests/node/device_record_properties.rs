use std::fs;
use std::sync::{Arc, Barrier};
use std::thread::{self, JoinHandle};

use orchestration_node::device_files::{AppServerRecord, DeviceFiles};
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

const SERVER_FILE_NAME: &str = "app-server.json";
const SERVER_ADDRESS_PREFIX: &str = "http://127.0.0.1:";
const SAVES_PER_WRITER: usize = 25;
const LEAST_WRITERS: usize = 2;
const MOST_WRITERS: usize = 8;
const CASE_COUNT: u32 = 12;

type WriterOutcome = Result<(), String>;

fn save_repeatedly(
    files: &DeviceFiles,
    writer: usize,
    barrier: &Barrier,
) -> WriterOutcome {
    barrier.wait();
    for save in 0..SAVES_PER_WRITER {
        let record = AppServerRecord {
            server_address: format!("{SERVER_ADDRESS_PREFIX}{writer}{save}"),
        };
        files
            .save_app_server(&record)
            .map_err(|error| error.to_string())?;
    }
    Ok(())
}

fn start_writers(
    files: &Arc<DeviceFiles>,
    writer_count: usize,
) -> Vec<JoinHandle<WriterOutcome>> {
    let barrier = Arc::new(Barrier::new(writer_count));
    let mut writers = Vec::new();
    for writer in 0..writer_count {
        let writer_files = Arc::clone(files);
        let writer_barrier = Arc::clone(&barrier);
        writers.push(thread::spawn(move || {
            save_repeatedly(&writer_files, writer, &writer_barrier)
        }));
    }
    writers
}

fn list_file_names(directory: &TempDir) -> Result<Vec<String>, TestCaseError> {
    let mut names = Vec::new();
    for entry in fs::read_dir(directory.path()).map_err(fail)? {
        let entry = entry.map_err(fail)?;
        names.push(entry.file_name().to_string_lossy().into_owned());
    }
    Ok(names)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_save_app_server_property_concurrent_saves_all_succeed(
        writer_count in LEAST_WRITERS..MOST_WRITERS,
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let files =
            Arc::new(DeviceFiles::open(directory.path()).map_err(fail)?);

        let writers = start_writers(&files, writer_count);
        for writer in writers {
            let outcome = writer
                .join()
                .map_err(|_| TestCaseError::fail("a writer panicked"))?;
            prop_assert!(outcome.is_ok(), "{outcome:?}");
        }
        let saved = files.load_app_server().map_err(fail)?;

        let saved_address = saved.map(|record| record.server_address);
        prop_assert!(
            saved_address
                .as_deref()
                .is_some_and(|address| address
                    .starts_with(SERVER_ADDRESS_PREFIX)),
            "{saved_address:?}"
        );
        prop_assert_eq!(
            list_file_names(&directory)?,
            vec![SERVER_FILE_NAME.to_owned()]
        );
    }
}
