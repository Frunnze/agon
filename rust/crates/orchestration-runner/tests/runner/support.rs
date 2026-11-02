use std::error::Error;
use std::fmt::Display;
use std::sync::{Mutex, MutexGuard, PoisonError};

use proptest::test_runner::TestCaseError;

pub type TestResult<T> = Result<T, Box<dyn Error>>;

pub fn hold<T>(lock: &Mutex<T>) -> MutexGuard<'_, T> {
    lock.lock().unwrap_or_else(PoisonError::into_inner)
}

pub fn to_case_error(problem: impl Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}
