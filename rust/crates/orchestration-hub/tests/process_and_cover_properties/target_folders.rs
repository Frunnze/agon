use std::fs;

use proptest::test_runner::TestCaseError;
use tempfile::TempDir;

const TARGET_TEMPORARY_ROOT: &str = env!("CARGO_TARGET_TMPDIR");
const FOLDER_PREFIX: &str = "process-and-cover-";

pub fn fail_with(problem: &impl ToString) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

pub fn create_target_folder() -> Result<TempDir, TestCaseError> {
    fs::create_dir_all(TARGET_TEMPORARY_ROOT)
        .map_err(|problem| fail_with(&problem))?;
    tempfile::Builder::new()
        .prefix(FOLDER_PREFIX)
        .tempdir_in(TARGET_TEMPORARY_ROOT)
        .map_err(|problem| fail_with(&problem))
}
