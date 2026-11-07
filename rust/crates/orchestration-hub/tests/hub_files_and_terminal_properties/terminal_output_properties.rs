use std::collections::BTreeMap;
use std::slice::from_ref;

use orchestration_hub::interactive_terminal::start_interactive_terminal;
use orchestration_hub::process_supervisor::SupervisorError;
use orchestration_hub::terminal_screen::TerminalSize;
use orchestration_hub::utf8_chunks::drain_complete_text;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::held_folders::{create_held_folders, to_case_error};
use crate::terminal_support::{
    TERMINAL_CASES, read_to_end, shell_command, start_command, start_script,
};

const PERCENT_BYTE: u8 = b'%';
const BACKSLASH_BYTE: u8 = b'\\';
const CUT_CHECK_MARK: &str = "\\342\\234";
const LARGEST_READ: usize = 4096;
const SMALL_SIZE: TerminalSize = TerminalSize {
    columns: 80,
    rows: 24,
};

fn any_printed_byte() -> impl Strategy<Value = u8> {
    prop_oneof![0x20_u8..0x7F, 0x80_u8..=0xFF]
        .prop_filter("printf would read the byte as a directive", |byte| {
            *byte != PERCENT_BYTE && *byte != BACKSLASH_BYTE
        })
}

fn octal_escapes(bytes: &[u8]) -> String {
    let mut escapes = Vec::new();
    for byte in bytes {
        escapes.push(format!("\\{byte:03o}"));
    }
    escapes.concat()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TERMINAL_CASES))]

    #[test]
    fn test_forward_output_text_property_printed_bytes_arrive_as_text(
        bytes in vec(any_printed_byte(), 0..80),
    ) {
        let script = format!("printf '{}'", octal_escapes(&bytes));
        let mut terminal = start_script(&script, &[])?;

        let output = read_to_end(&mut terminal);

        prop_assert_eq!(output, String::from_utf8_lossy(&bytes).into_owned());
    }

    #[test]
    fn test_forward_output_text_property_a_cut_last_character_is_shown(
        text in "[a-zA-Z0-9 é✓]{0,40}",
    ) {
        let script = format!("printf '%s{CUT_CHECK_MARK}' \"$1\"");
        let mut terminal = start_script(&script, from_ref(&text))?;

        let output = read_to_end(&mut terminal);

        prop_assert_eq!(output, format!("{text}\u{FFFD}"));
    }

    #[test]
    fn test_forward_output_text_property_long_output_arrives_whole(
        repeat_count in 1_usize..4,
        text in "[a-z✓]{1,8}",
    ) {
        let repeated = text.repeat(LARGEST_READ * repeat_count / text.len());
        let mut terminal =
            start_script("printf '%s' \"$1\"", from_ref(&repeated))?;

        let output = read_to_end(&mut terminal);

        prop_assert_eq!(output, repeated);
    }

    #[test]
    fn test_start_interactive_terminal_property_settings_reach_the_program(
        variable_value in "[a-zA-Z0-9_.]{1,20}",
    ) {
        let folders = create_held_folders().map_err(to_case_error)?;
        let folder = folders.temporary.path().canonicalize()
            .map_err(to_case_error)?;
        let environment = BTreeMap::from([(
            "ORCHESTRATION_TEST_VALUE".to_owned(),
            variable_value.clone(),
        )]);
        let script =
            "printf '%s|%s' \"$ORCHESTRATION_TEST_VALUE\" \"$(pwd -P)\"";
        let command =
            shell_command(script, &[], environment, Some(folder.clone()));
        let mut terminal = start_command(&command)?;

        let output = read_to_end(&mut terminal);

        let expected = format!("{variable_value}|{}", folder.display());
        prop_assert_eq!(output, expected);
    }

    #[test]
    fn test_start_interactive_terminal_property_missing_programs_never_start(
        name in "[a-z]{4,12}",
    ) {
        let program = format!("/nonexistent/{name}");
        let mut command = shell_command("", &[], BTreeMap::new(), None);
        command.program.clone_from(&program);
        command.arguments.clear();

        let started = start_interactive_terminal(&command, SMALL_SIZE);

        let Err(SupervisorError::StartProcess { program: named, .. }) = started
        else {
            return Err(TestCaseError::fail(format!("{started:?}")));
        };
        prop_assert_eq!(named, program);
    }
}

proptest! {
    #[test]
    fn test_measure_complete_bytes_property_invalid_bytes_keep_a_cut_character(
        valid_text in "[a-z✓]{0,6}",
        invalid_byte in 0x80_u8..0xC0,
        character in "[é✓中😀]",
        cut_position in 1_usize..4,
    ) {
        let mut bytes = valid_text.clone().into_bytes();
        bytes.push(invalid_byte);
        let character_bytes = character.as_bytes();
        let cut = cut_position.min(character_bytes.len() - 1);
        let mut pending = bytes.clone();
        pending.extend_from_slice(&character_bytes[..cut]);

        let mut joined = drain_complete_text(&mut pending);
        pending.extend_from_slice(&character_bytes[cut..]);
        joined.push_str(&drain_complete_text(&mut pending));

        bytes.extend_from_slice(character_bytes);
        prop_assert_eq!(joined, String::from_utf8_lossy(&bytes).into_owned());
        prop_assert!(pending.is_empty());
    }

    #[test]
    fn test_measure_complete_bytes_property_whole_text_drains_at_once(
        text in "\\PC{0,40}",
    ) {
        let mut pending = text.clone().into_bytes();

        let drained = drain_complete_text(&mut pending);

        prop_assert_eq!(drained, text);
        prop_assert!(pending.is_empty());
    }

    #[test]
    fn test_measure_complete_bytes_property_only_a_cut_tail_waits(
        bytes in vec(any::<u8>(), 0..40),
        character in "[é✓中😀]",
        cut_position in 1_usize..4,
    ) {
        let character_bytes = character.as_bytes();
        let cut = cut_position.min(character_bytes.len() - 1);
        let mut pending = bytes.clone();
        pending.extend_from_slice(&character_bytes[..cut]);

        let drained = drain_complete_text(&mut pending);

        prop_assert_eq!(pending.as_slice(), &character_bytes[..cut]);
        prop_assert_eq!(drained, String::from_utf8_lossy(&bytes).into_owned());
    }
}
