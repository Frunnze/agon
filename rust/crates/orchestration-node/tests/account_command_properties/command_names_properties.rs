use orchestration_node::commands::command_names;
use proptest::prelude::*;
use serde_json::json;

use crate::account_steps::{
    PARSING_CASES, account_command_name_strategy, harmless_command,
    read_error, shared_fresh_device,
};

const NAME_SEPARATOR: &str = "_";
const OTHER_SEPARATORS: [&str; 3] = ["-", " ", ""];
const REFUSED_PREFIXES: [&str; 3] =
    ["invalid arguments", "unknown", "a command"];

#[derive(Clone, Copy, Debug)]
enum Misspelling {
    Uppercase,
    OtherSeparator(usize),
    Padded,
    Suffixed,
}

fn misspelling_strategy() -> impl Strategy<Value = Misspelling> {
    prop_oneof![
        Just(Misspelling::Uppercase),
        (0..OTHER_SEPARATORS.len()).prop_map(Misspelling::OtherSeparator),
        Just(Misspelling::Padded),
        Just(Misspelling::Suffixed),
    ]
}

fn misspell(name: &str, misspelling: Misspelling) -> String {
    match misspelling {
        Misspelling::Uppercase => name.to_uppercase(),
        Misspelling::OtherSeparator(position) => {
            name.replace(NAME_SEPARATOR, OTHER_SEPARATORS[position])
        }
        Misspelling::Padded => format!(" {name} "),
        Misspelling::Suffixed => format!("{name}s"),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_account_command_names_property_each_name_is_listed_once(
        name in account_command_name_strategy(),
    ) {
        let names = command_names();

        let listings = names.iter().filter(|listed| **listed == name).count();

        prop_assert_eq!(listings, 1);
    }

    #[test]
    fn test_account_command_names_property_each_name_parses_as_a_command(
        name in account_command_name_strategy(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&harmless_command(name));

        let error = read_error(&reply);
        for refused_prefix in REFUSED_PREFIXES {
            prop_assert!(!error.starts_with(refused_prefix), "{reply}");
        }
    }

    #[test]
    fn test_account_command_names_property_misspelled_names_are_unknown(
        name in account_command_name_strategy(),
        misspelling in misspelling_strategy(),
    ) {
        let device = shared_fresh_device()?;
        let misspelled = misspell(name, misspelling);
        prop_assume!(misspelled != name);

        let reply = device.send(&json!({ "command": misspelled }));

        let expected = format!("unknown command: {misspelled}");
        prop_assert_eq!(read_error(&reply), expected);
    }
}
