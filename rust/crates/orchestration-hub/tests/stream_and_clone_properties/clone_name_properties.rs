use orchestration_hub::cached_clones::{
    decode_clone_folder_name, encode_clone_folder_name,
};
use proptest::prelude::*;

const ESCAPE_MARKER: char = '_';
const ESCAPE_LENGTH: usize = 3;
const HEXADECIMAL_RADIX: u32 = 16;
const LONGEST_FOLDER_NAME_BYTES: usize = 255;

fn is_kept_byte(byte: u8) -> bool {
    byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-'
}

fn encode_expected_byte(byte: u8) -> String {
    if is_kept_byte(byte) {
        return char::from(byte).to_string();
    }
    format!("{ESCAPE_MARKER}{byte:02x}")
}

fn expected_name_length(address: &str) -> usize {
    let mut length = 0;
    for byte in address.bytes() {
        length += if is_kept_byte(byte) { 1 } else { ESCAPE_LENGTH };
    }
    length
}

fn read_escaped_bytes(folder_name: &str) -> Option<Vec<u8>> {
    let characters: Vec<char> = folder_name.chars().collect();
    let mut bytes = Vec::new();
    let mut position = 0;
    while position < characters.len() {
        let character = characters[position];
        if character != ESCAPE_MARKER {
            bytes.push(u8::try_from(character).ok()?);
            position += 1;
            continue;
        }
        let high =
            characters.get(position + 1)?.to_digit(HEXADECIMAL_RADIX)?;
        let low = characters.get(position + 2)?.to_digit(HEXADECIMAL_RADIX)?;
        bytes.push(u8::try_from(high * HEXADECIMAL_RADIX + low).ok()?);
        position += ESCAPE_LENGTH;
    }
    Some(bytes)
}

fn has_lowercase_escapes_only(folder_name: &str) -> bool {
    let characters: Vec<char> = folder_name.chars().collect();
    for (position, character) in characters.iter().enumerate() {
        if *character != ESCAPE_MARKER {
            continue;
        }
        let digits = characters.get(position + 1..position + ESCAPE_LENGTH);
        let is_lowercase_hex = digits.is_some_and(|digits| {
            digits
                .iter()
                .all(|digit| matches!(digit, '0'..='9' | 'a'..='f'))
        });
        if !is_lowercase_hex {
            return false;
        }
    }
    true
}

proptest! {
    #[test]
    fn test_encode_clone_folder_name_property_joins_encoded_parts(
        first in any::<String>(),
        second in any::<String>(),
    ) {
        let joined_address = format!("{first}{second}");
        let joined_length = expected_name_length(&joined_address);
        prop_assume!(joined_length <= LONGEST_FOLDER_NAME_BYTES);

        let joined = encode_clone_folder_name(&joined_address);

        let parts = format!(
            "{}{}",
            encode_clone_folder_name(&first),
            encode_clone_folder_name(&second),
        );
        prop_assert_eq!(joined, parts);
    }

    #[test]
    fn test_encode_clone_folder_name_property_case_variants_stay_apart(
        address in "[a-zA-Z0-9./_-]{1,40}",
    ) {
        let variant = address.to_ascii_uppercase();
        let name = encode_clone_folder_name(&address);
        let variant_name = encode_clone_folder_name(&variant);

        let names_match = name.eq_ignore_ascii_case(&variant_name);
        prop_assert_eq!(names_match, address == variant);
    }

    #[test]
    fn test_encode_address_byte_property_counts_kept_and_escaped_bytes(
        address in any::<String>(),
    ) {
        let name = encode_clone_folder_name(&address);

        let expected_length = expected_name_length(&address);
        if expected_length <= LONGEST_FOLDER_NAME_BYTES {
            prop_assert_eq!(name.chars().count(), expected_length);
        } else {
            prop_assert!(name.len() <= LONGEST_FOLDER_NAME_BYTES);
        }
    }

    #[test]
    fn test_encode_address_byte_property_escapes_read_back_the_bytes(
        address in any::<String>(),
    ) {
        let name = encode_clone_folder_name(&address);

        prop_assert!(has_lowercase_escapes_only(&name));
        if expected_name_length(&address) <= LONGEST_FOLDER_NAME_BYTES {
            let expected = Some(address.into_bytes());
            prop_assert_eq!(read_escaped_bytes(&name), expected);
        }
    }

    #[test]
    fn test_encode_address_byte_property_each_ascii_byte_has_one_form(
        byte in 0_u8..0x80,
    ) {
        let address = char::from(byte).to_string();

        let expected = encode_expected_byte(byte);
        prop_assert_eq!(encode_clone_folder_name(&address), expected);
    }

    #[test]
    fn test_is_kept_character_property_kept_addresses_name_themselves(
        address in "[a-z0-9-]{0,40}",
    ) {
        prop_assert_eq!(encode_clone_folder_name(&address), address);
    }

    #[test]
    fn test_is_kept_character_property_uppercase_letters_are_escaped(
        letter in "[A-Z]",
    ) {
        let name = encode_clone_folder_name(&letter);

        prop_assert_eq!(name.chars().count(), ESCAPE_LENGTH);
        prop_assert!(!name.chars().any(char::is_uppercase));
        prop_assert_eq!(decode_clone_folder_name(&name), Some(letter));
    }

    #[test]
    fn test_is_kept_character_property_escape_marker_is_never_kept(
        address in "[a-z]{0,6}_[a-z_]{0,6}",
    ) {
        let name = encode_clone_folder_name(&address);

        let marker_count = address.matches(ESCAPE_MARKER).count();
        prop_assert_eq!(name.matches("_5f").count(), marker_count);
        prop_assert_eq!(decode_clone_folder_name(&name), Some(address));
    }

    #[test]
    fn test_decode_escaped_byte_property_escapes_read_back_characters(
        character in any::<char>(),
    ) {
        let address = character.to_string();
        let mut name_parts = Vec::new();
        for byte in address.bytes() {
            name_parts.push(encode_expected_byte(byte));
        }

        let name = name_parts.concat();
        prop_assert_eq!(decode_clone_folder_name(&name), Some(address));
    }

    #[test]
    fn test_decode_escaped_byte_property_non_hex_digits_are_refused(
        prefix in "[a-z0-9-]{0,6}",
        digits in "[+ g-zA-Z.][0-9a-f]|[0-9a-f][+ g-zA-Z.]|[A-F][0-9A-F]",
    ) {
        let name = format!("{prefix}{ESCAPE_MARKER}{digits}");

        prop_assert_eq!(decode_clone_folder_name(&name), None);
    }

    #[test]
    fn test_decode_escaped_byte_property_bytes_that_break_text_are_refused(
        prefix in "[a-z0-9-]{0,6}",
        byte in prop_oneof![0x80_u8..0xc0, 0xf8_u8..=0xff],
    ) {
        let name = format!("{prefix}{ESCAPE_MARKER}{byte:02x}");

        prop_assert_eq!(decode_clone_folder_name(&name), None);
    }

    #[test]
    fn test_decode_clone_folder_name_property_uppercase_escapes_refused(
        address in any::<String>(),
    ) {
        let name = encode_clone_folder_name(&address);
        let shouted = name.to_ascii_uppercase();

        let expected = (shouted == name).then_some(address);
        prop_assert_eq!(decode_clone_folder_name(&shouted), expected);
    }

    #[test]
    fn test_decode_clone_folder_name_property_cut_escapes_are_refused(
        address in "[a-z]{0,4}[A-Z./:@][a-z]{0,4}",
        cut in 1_usize..ESCAPE_LENGTH,
    ) {
        let name = encode_clone_folder_name(&address);
        let marker_position = name.find(ESCAPE_MARKER).unwrap_or_default();
        let cut_name = &name[..marker_position + cut];

        prop_assert_eq!(decode_clone_folder_name(cut_name), None);
    }
}
