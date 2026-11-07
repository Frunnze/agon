use proptest::prelude::*;

use crate::screen_support::{
    BELL, ESCAPE, STRING_TERMINATOR, any_charset_designation,
    any_control_string, any_operating_system_command, any_parameters,
    any_plain_text, any_string_payload, any_two_character_escape, show,
    shown_alone,
};
use crate::text_shapes::{any_code_placements, insert_codes};

fn any_restarting_prefix() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(ESCAPE.to_owned()),
        any_parameters()
            .prop_map(|parameters| format!("{ESCAPE}[{parameters}")),
        "[ -/]{1,2}"
            .prop_map(|intermediates| format!("{ESCAPE}{intermediates}")),
        any_string_payload().prop_map(|payload| format!("{ESCAPE}]{payload}")),
        any_string_payload().prop_map(|payload| format!("{ESCAPE}P{payload}")),
    ]
}

proptest! {
    #[test]
    fn test_read_escape_property_two_character_escapes_hide_one_character(
        text in any_plain_text(),
        placements in any_code_placements(any_two_character_escape()),
    ) {
        let noisy = insert_codes(&text, &placements);

        prop_assert_eq!(show(&noisy), shown_alone(&text));
    }

    #[test]
    fn test_read_escape_property_character_set_choices_are_hidden(
        text in any_plain_text(),
        placements in any_code_placements(any_charset_designation()),
    ) {
        let noisy = insert_codes(&text, &placements);

        prop_assert_eq!(show(&noisy), shown_alone(&text));
    }

    #[test]
    fn test_read_escape_property_a_new_escape_starts_a_new_sequence(
        before in any_plain_text(),
        unfinished in any_restarting_prefix(),
        parameters in any_parameters(),
        after in any_plain_text(),
    ) {
        let colour = format!("{ESCAPE}[{parameters}m");
        let output = format!("{before}{unfinished}{colour}{after}");

        prop_assert_eq!(
            show(&output),
            shown_alone(&format!("{before}{after}"))
        );
    }

    #[test]
    fn test_read_control_string_property_titles_are_hidden(
        text in any_plain_text(),
        placements in any_code_placements(any_operating_system_command()),
    ) {
        let noisy = insert_codes(&text, &placements);

        prop_assert_eq!(show(&noisy), shown_alone(&text));
    }

    #[test]
    fn test_read_control_string_property_device_strings_are_hidden(
        text in any_plain_text(),
        placements in any_code_placements(any_control_string()),
    ) {
        let noisy = insert_codes(&text, &placements);

        prop_assert_eq!(show(&noisy), shown_alone(&text));
    }

    #[test]
    fn test_read_control_string_property_hides_until_the_end(
        payload in any_string_payload(),
        after in any_plain_text(),
        is_ended_by_bell in any::<bool>(),
    ) {
        let terminator = if is_ended_by_bell {
            BELL
        } else {
            STRING_TERMINATOR
        };
        let ended = format!("{ESCAPE}]{payload}{terminator}{after}");
        let unended = format!("{ESCAPE}]{payload}{after}");

        prop_assert_eq!(show(&ended), shown_alone(&after));
        prop_assert_eq!(show(&unended), Vec::<String>::new());
    }
}
