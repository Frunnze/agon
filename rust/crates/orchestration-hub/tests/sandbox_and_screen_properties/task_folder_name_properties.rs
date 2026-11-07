use orchestration_core::identifiers::TaskId;
use orchestration_hub::task_folder_names::read_task_id;
use proptest::prelude::*;
use uuid::Uuid;

const SLUG_PATTERN: &str = "[a-z0-9]{1,8}(-[a-z0-9]{1,8}){0,3}";
const SMALL_NUMBER_LIMIT: u128 = 100_000_000;
const SIMPLE_IDENTIFIER_LENGTH: usize = 32;

fn any_task_id() -> impl Strategy<Value = TaskId> {
    prop_oneof![0..SMALL_NUMBER_LIMIT, any::<u128>()]
        .prop_map(|number| TaskId(Uuid::from_u128(number)))
}

fn task_folder_name(slug: &str, task_id: TaskId) -> String {
    format!("{slug}-{}", task_id.0.simple())
}

proptest! {
    #[test]
    fn test_strip_run_number_property_run_folders_name_the_same_task(
        slug in SLUG_PATTERN,
        task_id in any_task_id(),
        run_number in any::<u32>(),
    ) {
        let task_folder = task_folder_name(&slug, task_id);
        let run_folder = format!("{task_folder}-run-{run_number}");

        prop_assert_eq!(read_task_id(&task_folder), Some(task_id));
        prop_assert_eq!(read_task_id(&run_folder), Some(task_id));
    }

    #[test]
    fn test_strip_run_number_property_titles_ending_in_run_keep_their_task(
        slug_start in "[a-z0-9]{1,8}",
        task_id in (0..SMALL_NUMBER_LIMIT)
            .prop_map(|number| TaskId(Uuid::from_u128(number))),
    ) {
        let slug = format!("{slug_start}-run");
        let task_folder = task_folder_name(&slug, task_id);

        prop_assert_eq!(read_task_id(&task_folder), Some(task_id));
    }

    #[test]
    fn test_strip_run_number_property_only_digit_run_numbers_are_removed(
        slug in SLUG_PATTERN,
        task_id in any_task_id(),
        run_suffix in prop_oneof![
            Just(String::new()),
            "[0-9]{0,4}[a-z ][0-9]{0,4}",
            "[+-][0-9]{1,4}",
        ],
    ) {
        let run_folder =
            format!("{}-run-{run_suffix}", task_folder_name(&slug, task_id));

        prop_assert_eq!(read_task_id(&run_folder), None);
    }

    #[test]
    fn test_is_simple_identifier_property_hyphenated_identifiers_are_skipped(
        slug in SLUG_PATTERN,
        task_id in any_task_id(),
    ) {
        let folder_name = format!("{slug}-{}", task_id.0.hyphenated());

        prop_assert_eq!(read_task_id(&folder_name), None);
    }

    #[test]
    fn test_is_simple_identifier_property_upper_case_identifiers_are_skipped(
        slug in SLUG_PATTERN,
        task_id in any_task_id(),
    ) {
        let identifier = task_id.0.simple().to_string();
        let upper_case = identifier.to_ascii_uppercase();
        prop_assume!(upper_case != identifier);
        let folder_name = format!("{slug}-{upper_case}");

        prop_assert_eq!(read_task_id(&folder_name), None);
    }

    #[test]
    fn test_is_simple_identifier_property_only_32_digits_are_read(
        slug in SLUG_PATTERN,
        identifier in "[0-9a-f]{1,40}",
    ) {
        let folder_name = format!("{slug}-{identifier}");

        let read = read_task_id(&folder_name);

        let is_simple = identifier.len() == SIMPLE_IDENTIFIER_LENGTH;
        prop_assert_eq!(read.is_some(), is_simple);
        if let Some(task_id) = read {
            prop_assert_eq!(task_id.0.simple().to_string(), identifier);
        }
    }

    #[test]
    fn test_read_ending_task_id_property_reads_after_the_last_dash(
        slug in SLUG_PATTERN,
        task_id in any_task_id(),
    ) {
        let folder_name = task_folder_name(&slug, task_id);

        prop_assert_eq!(read_task_id(&folder_name), Some(task_id));
    }

    #[test]
    fn test_read_ending_task_id_property_a_bare_identifier_is_skipped(
        task_id in any_task_id(),
    ) {
        let identifier = task_id.0.simple().to_string();

        prop_assert_eq!(read_task_id(&identifier), None);
    }

    #[test]
    fn test_read_ending_task_id_property_run_titled_runs_keep_their_task(
        slug_start in "[a-z0-9]{1,8}",
        task_id in any_task_id(),
        run_number in any::<u32>(),
    ) {
        let slug = format!("{slug_start}-run");
        let task_folder = task_folder_name(&slug, task_id);
        let run_folder = format!("{task_folder}-run-{run_number}");

        prop_assert_eq!(read_task_id(&run_folder), Some(task_id));
    }
}
