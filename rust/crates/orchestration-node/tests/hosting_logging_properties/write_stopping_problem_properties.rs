use orchestration_node::describe_write_stopping_problem;
use orchestration_server::ServerError;
use proptest::prelude::*;

const LOG_LINE_START: &str =
    "the stopped app server could not refuse writes: ";
const FIXED_TEXTS: [&str; 3] =
    ["the server state lock is poisoned", "the run", ""];

fn fixed_text_strategy() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(&FIXED_TEXTS[..])
}

fn server_error_strategy() -> impl Strategy<Value = ServerError> {
    prop_oneof![
        fixed_text_strategy().prop_map(ServerError::Unauthenticated),
        fixed_text_strategy().prop_map(ServerError::Forbidden),
        fixed_text_strategy().prop_map(ServerError::NotFound),
        fixed_text_strategy().prop_map(ServerError::Internal),
        "\\PC{0,60}".prop_map(ServerError::Conflict),
        "\\PC{0,60}".prop_map(ServerError::Invalid),
        "\\PC{0,60}".prop_map(ServerError::Storage),
        Just(ServerError::NotActive),
        proptest::collection::vec("[a-z ]{0,12}", 0..4)
            .prop_map(ServerError::UnmatchedAnswer),
    ]
}

proptest! {
    #[test]
    fn test_describe_write_stopping_problem_property_names_the_stop(
        problem in server_error_strategy(),
    ) {
        let line = describe_write_stopping_problem(&problem);

        prop_assert!(line.starts_with(LOG_LINE_START), "{}", line);
    }

    #[test]
    fn test_describe_write_stopping_problem_property_ends_with_the_problem(
        problem in server_error_strategy(),
    ) {
        let line = describe_write_stopping_problem(&problem);

        let problem_text = problem.to_string();
        prop_assert_eq!(
            line.strip_prefix(LOG_LINE_START),
            Some(problem_text.as_str())
        );
    }

    #[test]
    fn test_describe_write_stopping_problem_property_tells_problems_apart(
        first in server_error_strategy(),
        second in server_error_strategy(),
    ) {
        let first_line = describe_write_stopping_problem(&first);
        let second_line = describe_write_stopping_problem(&second);

        let is_same_text = first.to_string() == second.to_string();
        prop_assert_eq!(first_line == second_line, is_same_text);
    }
}
