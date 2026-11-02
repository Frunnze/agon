use std::path::PathBuf;

use orchestration_server::{CommandLine, parse_command_line};
use proptest::prelude::*;

const LISTEN_OPTION: &str = "--listen";
const DATA_DIRECTORY_OPTION: &str = "--data-directory";
const PUBLIC_ADDRESS_OPTION: &str = "--public-address";

fn arguments(texts: &[&str]) -> Vec<String> {
    texts.iter().map(|text| (*text).to_owned()).collect()
}

fn ordered_arguments(
    option_pairs: &[[&str; 2]],
    order_seed: usize,
) -> Vec<String> {
    let mut rotated_pairs = option_pairs.to_vec();
    rotated_pairs.rotate_left(order_seed % option_pairs.len());
    let mut texts = Vec::new();
    for [option, value] in rotated_pairs {
        texts.push(option.to_owned());
        texts.push(value.to_owned());
    }
    texts
}

proptest! {
    #[test]
    fn test_parse_command_line_property_reads_options_in_any_order(
        address in "[a-z0-9.:]{1,30}",
        directory in "[a-zA-Z0-9/_.-]{1,40}",
        public_host in proptest::option::of("[a-z]{1,12}\\.[a-z]{2,6}"),
        order_seed in 0_usize..3,
    ) {
        let public_url =
            public_host.map(|host| format!("https://{host}"));
        let mut option_pairs = vec![
            [LISTEN_OPTION, address.as_str()],
            [DATA_DIRECTORY_OPTION, directory.as_str()],
        ];
        if let Some(url) = &public_url {
            option_pairs.push([PUBLIC_ADDRESS_OPTION, url.as_str()]);
        }

        let texts = ordered_arguments(&option_pairs, order_seed);
        let command_line = parse_command_line(texts);

        let expected_public_address =
            public_url.unwrap_or_else(|| address.clone());
        prop_assert_eq!(
            command_line,
            Ok(CommandLine {
                listen_address: address,
                data_directory: PathBuf::from(directory),
                public_address: expected_public_address,
            })
        );
    }

    #[test]
    fn test_parse_command_line_property_rejects_non_web_public_addresses(
        address in "[a-z]{1,8}://[a-z]{1,12}|[a-z.]{1,20}",
    ) {
        let is_web_address =
            address.starts_with("http://") || address.starts_with("https://");
        prop_assume!(!is_web_address);
        let texts = [
            LISTEN_OPTION,
            "0.0.0.0:8080",
            DATA_DIRECTORY_OPTION,
            "/var/lib/orchestration",
            PUBLIC_ADDRESS_OPTION,
            address.as_str(),
        ];

        prop_assert!(parse_command_line(arguments(&texts)).is_err());
    }

    #[test]
    fn test_parse_command_line_property_rejects_unknown_options(
        option in "--[a-z]{1,12}",
    ) {
        prop_assume!(option != LISTEN_OPTION);
        prop_assume!(option != DATA_DIRECTORY_OPTION);
        let texts = [
            LISTEN_OPTION,
            "0.0.0.0:8080",
            DATA_DIRECTORY_OPTION,
            "/var/lib/orchestration",
            option.as_str(),
            "value",
        ];

        prop_assert!(parse_command_line(arguments(&texts)).is_err());
    }

    #[test]
    fn test_parse_command_line_property_never_panics(
        texts in proptest::collection::vec("\\PC{0,20}", 0..8),
    ) {
        let parsed = parse_command_line(texts);

        prop_assert!(parsed.is_ok() || parsed.is_err());
    }
}

#[test]
fn listen_and_data_directory_are_required() {
    let only_listen = arguments(&[LISTEN_OPTION, "127.0.0.1:8080"]);
    let only_data = arguments(&[DATA_DIRECTORY_OPTION, "/tmp/data"]);
    let dangling = arguments(&[LISTEN_OPTION]);

    assert!(parse_command_line(only_listen).is_err());
    assert!(parse_command_line(only_data).is_err());
    assert!(parse_command_line(dangling).is_err());
}
