use orchestration_hub::interactive_terminal::InteractiveTerminal;
use proptest::prelude::*;

use crate::terminal_support::{TERMINAL_CASES, read_to_end, start_script};

const KEYBOARD_DEBUG: &str = "TerminalKeyboard { .. }";
const STOPPER_DEBUG: &str = "TerminalStopper { .. }";
const PROCESS_DEBUG: &str = "TerminalProcess { .. }";
const HIDDEN_FIELDS: [&str; 3] = ["writer", "killer", "child"];

fn start_finished_terminal(
    code: u8,
) -> Result<InteractiveTerminal, TestCaseError> {
    let mut terminal = start_script("exit \"$1\"", &[code.to_string()])?;
    let _output = read_to_end(&mut terminal);
    Ok(terminal)
}

fn shows_no_hidden_field(debug_text: &str) -> bool {
    HIDDEN_FIELDS
        .iter()
        .all(|field| !debug_text.contains(field))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TERMINAL_CASES))]

    #[test]
    fn test_terminal_keyboard_fmt_property_names_only_the_type(
        code in any::<u8>(),
    ) {
        let terminal = start_finished_terminal(code)?;

        prop_assert_eq!(format!("{:?}", terminal.keyboard), KEYBOARD_DEBUG);
    }

    #[test]
    fn test_terminal_keyboard_fmt_property_pretty_form_hides_the_writer(
        code in any::<u8>(),
    ) {
        let terminal = start_finished_terminal(code)?;

        let pretty = format!("{:#?}", terminal.keyboard);

        prop_assert!(pretty.starts_with("TerminalKeyboard"));
        prop_assert!(shows_no_hidden_field(&pretty), "{}", pretty);
    }

    #[test]
    fn test_terminal_keyboard_fmt_property_terminals_look_alike(
        first_code in any::<u8>(),
        second_code in any::<u8>(),
    ) {
        let first = start_finished_terminal(first_code)?;
        let second = start_finished_terminal(second_code)?;

        let first_text = format!("{:?}", first.keyboard);
        prop_assert_eq!(first_text, format!("{:?}", second.keyboard));
    }

    #[test]
    fn test_terminal_stopper_fmt_property_names_only_the_type(
        code in any::<u8>(),
    ) {
        let terminal = start_finished_terminal(code)?;

        prop_assert_eq!(format!("{:?}", terminal.stopper), STOPPER_DEBUG);
    }

    #[test]
    fn test_terminal_stopper_fmt_property_pretty_form_hides_the_killer(
        code in any::<u8>(),
    ) {
        let terminal = start_finished_terminal(code)?;

        let pretty = format!("{:#?}", terminal.stopper);

        prop_assert!(pretty.starts_with("TerminalStopper"));
        prop_assert!(shows_no_hidden_field(&pretty), "{}", pretty);
    }

    #[test]
    fn test_terminal_stopper_fmt_property_terminals_look_alike(
        first_code in any::<u8>(),
        second_code in any::<u8>(),
    ) {
        let first = start_finished_terminal(first_code)?;
        let second = start_finished_terminal(second_code)?;

        let first_text = format!("{:?}", first.stopper);
        prop_assert_eq!(first_text, format!("{:?}", second.stopper));
    }

    #[test]
    fn test_terminal_process_fmt_property_names_only_the_type(
        code in any::<u8>(),
    ) {
        let terminal = start_finished_terminal(code)?;

        prop_assert_eq!(format!("{:?}", terminal.process), PROCESS_DEBUG);
    }

    #[test]
    fn test_terminal_process_fmt_property_pretty_form_hides_the_child(
        code in any::<u8>(),
    ) {
        let terminal = start_finished_terminal(code)?;

        let pretty = format!("{:#?}", terminal.process);

        prop_assert!(pretty.starts_with("TerminalProcess"));
        prop_assert!(shows_no_hidden_field(&pretty), "{}", pretty);
    }

    #[test]
    fn test_terminal_process_fmt_property_whole_terminal_shows_each_part(
        code in any::<u8>(),
    ) {
        let terminal = start_finished_terminal(code)?;

        let whole = format!("{terminal:?}");

        prop_assert!(whole.contains(KEYBOARD_DEBUG), "{}", whole);
        prop_assert!(whole.contains(STOPPER_DEBUG), "{}", whole);
        prop_assert!(whole.contains(PROCESS_DEBUG), "{}", whole);
    }
}
