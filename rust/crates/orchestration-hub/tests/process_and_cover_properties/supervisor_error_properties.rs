use std::io;

use orchestration_hub::process_supervisor::SupervisorError;
use proptest::prelude::*;

type ErrorMaker = fn(&str) -> SupervisorError;

const TEXT_CARRYING_ERRORS: [ErrorMaker; 6] = [
    terminal_error,
    reading_error,
    stop_error,
    wait_error,
    write_error,
    start_error,
];

fn terminal_error(reason: &str) -> SupervisorError {
    SupervisorError::OpenTerminal(reason.to_owned())
}

fn reading_error(reason: &str) -> SupervisorError {
    SupervisorError::ReadOutput(reason.to_owned())
}

fn stop_error(reason: &str) -> SupervisorError {
    SupervisorError::StopProcess(io::Error::other(reason.to_owned()))
}

fn wait_error(reason: &str) -> SupervisorError {
    SupervisorError::WaitForProcess(io::Error::other(reason.to_owned()))
}

fn write_error(reason: &str) -> SupervisorError {
    SupervisorError::WriteInput(io::Error::other(reason.to_owned()))
}

fn start_error(reason: &str) -> SupervisorError {
    SupervisorError::StartProcess {
        program: "claude".to_owned(),
        reason: reason.to_owned(),
    }
}

fn any_error_maker() -> impl Strategy<Value = ErrorMaker> {
    proptest::sample::select(TEXT_CARRYING_ERRORS.to_vec())
}

proptest! {
    #[test]
    fn test_supervisor_error_fmt_property_ends_with_the_reason(
        make_error in any_error_maker(),
        reason in "[a-zA-Z0-9é /:._-]{1,30}",
    ) {
        let message = make_error(&reason).to_string();

        prop_assert!(message.ends_with(&reason), "{message}");
        prop_assert!(message.starts_with("could not "), "{message}");
    }

    #[test]
    fn test_supervisor_error_fmt_property_names_the_program_that_failed(
        program in "[a-zA-Z0-9/._-]{1,20}",
        reason in "[a-zA-Z0-9 ]{0,20}",
    ) {
        let error = SupervisorError::StartProcess {
            program: program.clone(),
            reason: reason.clone(),
        };

        let expected = format!("could not start {program}: {reason}");
        prop_assert_eq!(error.to_string(), expected);
    }

    #[test]
    fn test_supervisor_error_fmt_property_kinds_read_differently(
        first_kind in 0..TEXT_CARRYING_ERRORS.len(),
        second_kind in 0..TEXT_CARRYING_ERRORS.len(),
        reason in "[a-z]{1,10}",
    ) {
        let first = TEXT_CARRYING_ERRORS[first_kind](&reason).to_string();
        let second = TEXT_CARRYING_ERRORS[second_kind](&reason).to_string();

        prop_assert_eq!(first == second, first_kind == second_kind);
        prop_assert_ne!(SupervisorError::OpenPipes.to_string(), first);
    }
}
