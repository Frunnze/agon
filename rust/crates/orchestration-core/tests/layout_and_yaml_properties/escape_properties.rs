use proptest::prelude::*;

use crate::yaml_reading::decode_yaml_scalar;
use crate::yaml_scalar_properties::render_task;

const LARGEST_SHORT_ESCAPE: char = '\u{FFFF}';
const BASIC_PLANE_HIDDEN_SAMPLES: [char; 10] = [
    '\u{AD}', '\u{34F}', '\u{61C}', '\u{115F}', '\u{180E}', '\u{200D}',
    '\u{2066}', '\u{3164}', '\u{FE0F}', '\u{FFFF}',
];

fn basic_plane_hidden_character() -> impl Strategy<Value = char> {
    prop_oneof![
        proptest::char::range('\u{0}', '\u{8}'),
        proptest::char::range('\u{B}', '\u{1F}'),
        proptest::char::range('\u{7F}', '\u{9F}'),
        proptest::sample::select(BASIC_PLANE_HIDDEN_SAMPLES.to_vec()),
    ]
}

fn far_plane_hidden_character() -> impl Strategy<Value = char> {
    prop_oneof![
        proptest::char::range('\u{E0000}', '\u{E0FFF}'),
        proptest::char::range('\u{1D173}', '\u{1D17A}'),
        proptest::char::range('\u{1BCA0}', '\u{1BCA3}'),
    ]
}

proptest! {
    #[test]
    fn test_escape_hidden_character_property_basic_plane_uses_four_digits(
        hidden in basic_plane_hidden_character(),
    ) {
        let rendered = render_task(&format!("a{hidden}b"));

        let code_point = u32::from(hidden);
        prop_assert_eq!(rendered, format!("\"a\\u{code_point:04X}b\""));
    }

    #[test]
    fn test_escape_hidden_character_property_far_planes_use_eight_digits(
        hidden in far_plane_hidden_character(),
    ) {
        let rendered = render_task(&format!("a{hidden}b"));

        let code_point = u32::from(hidden);
        prop_assert_eq!(rendered, format!("\"a\\U{code_point:08X}b\""));
    }

    #[test]
    fn test_escape_hidden_character_property_every_escape_decodes_back(
        hidden in prop_oneof![
            basic_plane_hidden_character(),
            far_plane_hidden_character(),
        ],
        trailing_digits in "[0-9A-F]{0,8}",
    ) {
        let task = format!("{hidden}{trailing_digits}");

        let rendered = render_task(&task);

        prop_assert_eq!(decode_yaml_scalar(&rendered), Some(task));
        prop_assert_eq!(
            rendered.contains("\\U"),
            hidden > LARGEST_SHORT_ESCAPE
        );
    }
}
