use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{LocalFolder, render_local_address};
use orchestration_core::repository_address::parse_repository_address;
use orchestration_hub::clone_source::{
    ADDRESS_PLACEHOLDER, CloneSource, CloneSourceProblem,
    STANDARD_CLONE_TEMPLATE,
};
use proptest::prelude::*;

fn any_canonical_address() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9-]{0,7}\\.[a-z]{2,4}/[a-zA-Z0-9_-]{1,10}/[a-zA-Z0-9_.-]{1,12}"
        .prop_filter("the address is canonical", |address| {
            parse_repository_address(address).as_deref() == Ok(address)
        })
}

fn any_device_id() -> impl Strategy<Value = DeviceId> {
    "[a-z0-9-]{1,16}".prop_map(DeviceId)
}

fn any_folder_path() -> impl Strategy<Value = String> {
    prop_oneof![
        "(/[A-Za-z0-9 é_.-]{0,6}[A-Za-z0-9é_-]){1,4}",
        "[A-Z]:\\\\[A-Za-z0-9_-]{1,8}(\\\\[A-Za-z0-9_-]{1,8}){0,2}",
    ]
}

fn any_template() -> impl Strategy<Value = String> {
    ("[a-zA-Z0-9:/@._~+-]{0,20}", "[a-zA-Z0-9:/._~+-]{0,20}").prop_map(
        |(prefix, suffix)| format!("{prefix}{ADDRESS_PLACEHOLDER}{suffix}"),
    )
}

fn any_text() -> impl Strategy<Value = String> {
    prop_oneof![any::<String>(), "[a-z{}\n\t\" ]{0,20}"]
}

fn local_address(
    device_id: &DeviceId,
    path: &str,
) -> Result<String, TestCaseError> {
    let folder = LocalFolder {
        device_id: device_id.clone(),
        path: path.to_owned(),
    };
    render_local_address(&folder)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

fn source_from(template: &str) -> Result<CloneSource, TestCaseError> {
    CloneSource::from_template(template)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

proptest! {
    #[test]
    fn test_standard_property_clones_canonical_addresses_over_https(
        address in any_canonical_address(),
    ) {
        let clone_url = CloneSource::standard().clone_url(&address);

        prop_assert_eq!(clone_url, Ok(format!("https://{address}.git")));
    }

    #[test]
    fn test_standard_property_equals_its_template_source(
        address in any_canonical_address(),
    ) {
        let from_template = source_from(STANDARD_CLONE_TEMPLATE)?;

        prop_assert_eq!(&CloneSource::standard(), &from_template);
        prop_assert_eq!(
            CloneSource::standard().clone_url(&address),
            from_template.clone_url(&address),
        );
    }

    #[test]
    fn test_from_template_property_problem_names_the_exact_template(
        template in any_template(),
        unsafe_text in "[ \t\n\r\u{0}\u{7f}]{1,3}",
    ) {
        let unsafe_template = format!("{template}{unsafe_text}");
        let doubled_template = format!("{template}{ADDRESS_PLACEHOLDER}");

        let unsafe_problem = CloneSource::from_template(&unsafe_template);
        let doubled_problem = CloneSource::from_template(&doubled_template);

        let expected = CloneSourceProblem::InvalidTemplate(unsafe_template);
        prop_assert_eq!(unsafe_problem, Err(expected));
        let expected = CloneSourceProblem::InvalidTemplate(doubled_template);
        prop_assert_eq!(doubled_problem, Err(expected));
    }

    #[test]
    fn test_on_device_property_the_last_device_wins(
        first_device in any_device_id(),
        second_device in any_device_id(),
        path in any_folder_path(),
    ) {
        prop_assume!(first_device != second_device);
        let source = CloneSource::standard()
            .on_device(first_device.clone())
            .on_device(second_device.clone());
        let first_folder = local_address(&first_device, &path)?;
        let second_folder = local_address(&second_device, &path)?;

        let refused = CloneSourceProblem::FolderOnAnotherDevice(
            first_folder.clone(),
        );
        prop_assert_eq!(source.clone_url(&first_folder), Err(refused));
        prop_assert_eq!(source.clone_url(&second_folder), Ok(path));
    }

    #[test]
    fn test_on_device_property_keeps_custom_templates(
        template in any_template(),
        device_id in any_device_id(),
        address in any_canonical_address(),
    ) {
        let source = source_from(&template)?;
        let on_device = source.clone().on_device(device_id);

        prop_assert_ne!(&on_device, &source);
        let expected = source.clone_url(&address);
        prop_assert_eq!(on_device.clone_url(&address), expected);
    }

    #[test]
    fn test_folder_path_property_returns_the_folder_path(
        device_id in any_device_id(),
        path in any_folder_path(),
    ) {
        let address = local_address(&device_id, &path)?;
        let source = CloneSource::standard().on_device(device_id);

        let clone_url = source.clone_url(&address);

        prop_assert_eq!(clone_url, Ok(path));
    }

    #[test]
    fn test_folder_path_property_non_canonical_folders_are_refused(
        device_id in any_device_id(),
        path in any_folder_path(),
        noise in prop_oneof![Just("/"), Just(" "), Just("//"), Just("\\")],
    ) {
        let address = local_address(&device_id, &path)?;
        let noisy_address = format!("{address}{noise}");
        let source = CloneSource::standard().on_device(device_id);

        let expected =
            CloneSourceProblem::NonCanonicalAddress(noisy_address.clone());
        prop_assert_eq!(source.clone_url(&noisy_address), Err(expected));
    }

    #[test]
    fn test_folder_path_property_device_ids_must_match_exactly(
        device_id in any_device_id(),
        extra in "[a-z0-9-]{1,4}",
        path in any_folder_path(),
    ) {
        let address = local_address(&device_id, &path)?;
        let longer_device = DeviceId(format!("{}{extra}", device_id.0));
        let shorter_source = CloneSource::standard().on_device(longer_device);

        let expected =
            CloneSourceProblem::FolderOnAnotherDevice(address.clone());
        prop_assert_eq!(shorter_source.clone_url(&address), Err(expected));
    }

    #[test]
    fn test_clone_source_problem_fmt_property_quotes_the_template(
        template in any_text(),
    ) {
        let problem = CloneSourceProblem::InvalidTemplate(template.clone());

        let message = problem.to_string();

        let quoted = format!("{template:?}");
        prop_assert!(message.contains(&quoted));
        prop_assert!(message.contains(ADDRESS_PLACEHOLDER));
    }

    #[test]
    fn test_clone_source_problem_fmt_property_quotes_the_address(
        address in any_text(),
    ) {
        let non_canonical =
            CloneSourceProblem::NonCanonicalAddress(address.clone());
        let elsewhere =
            CloneSourceProblem::FolderOnAnotherDevice(address.clone());

        let quoted = format!("{address:?}");
        prop_assert!(non_canonical.to_string().contains(&quoted));
        prop_assert!(elsewhere.to_string().contains(&quoted));
        prop_assert_ne!(non_canonical.to_string(), elsewhere.to_string());
    }

    #[test]
    fn test_clone_source_problem_fmt_property_messages_are_one_line(
        text in any_text(),
    ) {
        let problems = [
            CloneSourceProblem::InvalidTemplate(text.clone()),
            CloneSourceProblem::NonCanonicalAddress(text.clone()),
            CloneSourceProblem::FolderOnAnotherDevice(text),
        ];

        for problem in problems {
            prop_assert!(!problem.to_string().contains(['\n', '\r']));
        }
    }
}
