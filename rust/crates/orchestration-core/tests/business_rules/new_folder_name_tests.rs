use orchestration_core::local_folders::{
    LocalFolderProblem, validate_new_folder_name,
};
use proptest::prelude::*;

fn safe_folder_name() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_-][A-Za-z0-9 _.-]{0,20}[A-Za-z0-9_-]"
}

fn unsafe_folder_name() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        Just(".".to_owned()),
        Just("..".to_owned()),
        "[ ]{1,4}",
        "[a-z]{0,6}[/\\\\][a-z]{0,6}",
        "[a-z]{0,6}[\\x00-\\x1f][a-z]{0,6}",
    ]
}

proptest! {
    #[test]
    fn test_validate_new_folder_name_property_safe_names_pass(
        name in safe_folder_name(),
    ) {
        prop_assert_eq!(validate_new_folder_name(&name), Ok(()));
    }

    #[test]
    fn test_validate_new_folder_name_property_unsafe_names_are_refused(
        name in unsafe_folder_name(),
    ) {
        prop_assert_eq!(
            validate_new_folder_name(&name),
            Err(LocalFolderProblem::UnsafeFolderName(name.clone()))
        );
    }
}
