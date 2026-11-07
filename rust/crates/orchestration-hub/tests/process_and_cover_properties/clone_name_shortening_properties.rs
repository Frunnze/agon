use orchestration_hub::cached_clones::encode_clone_folder_name;
use proptest::prelude::*;
use sha2::{Digest, Sha256};

use crate::clone_name_support::{
    ESCAPE_MARKER, LONGEST_FOLDER_NAME_BYTES, any_address, any_long_address,
    escape_like_today, split_shortened_name,
};

const HASH_LENGTH: usize = 64;
const ESCAPE_LENGTH: usize = 3;
const SHORTENED_START_BYTES: usize =
    LONGEST_FOLDER_NAME_BYTES - HASH_LENGTH - 1;

fn shortened_parts(address: &str) -> Result<(String, String), TestCaseError> {
    let name = encode_clone_folder_name(address);
    let (start, hash) = split_shortened_name(&name).ok_or_else(|| {
        TestCaseError::fail(format!("not shortened: {name}"))
    })?;
    Ok((start.to_owned(), hash.to_owned()))
}

fn has_whole_escapes_only(text: &str) -> bool {
    let characters: Vec<char> = text.chars().collect();
    for (position, character) in characters.iter().enumerate() {
        if *character != ESCAPE_MARKER {
            continue;
        }
        let digits = characters.get(position + 1..position + ESCAPE_LENGTH);
        let is_whole = digits.is_some_and(|digits| {
            digits
                .iter()
                .all(|digit| matches!(digit, '0'..='9' | 'a'..='f'))
        });
        if !is_whole {
            return false;
        }
    }
    true
}

fn expected_hash(address: &str) -> String {
    let digest = Sha256::digest(address.as_bytes());
    let mut hexadecimal_pairs = Vec::new();
    for byte in &digest {
        hexadecimal_pairs.push(format!("{byte:02x}"));
    }
    hexadecimal_pairs.concat()
}

fn needs_shortening(address: &str) -> bool {
    escape_like_today(address).len() > LONGEST_FOLDER_NAME_BYTES
}

fn any_shortened_address() -> impl Strategy<Value = String> {
    any_long_address()
        .prop_filter("an address that needs shortening", |address| {
            needs_shortening(address)
        })
}

proptest! {
    #[test]
    fn test_escape_address_property_matches_the_byte_by_byte_model(
        address in any_address(),
    ) {
        prop_assume!(!needs_shortening(&address));

        let name = encode_clone_folder_name(&address);

        prop_assert_eq!(name, escape_like_today(&address));
    }

    #[test]
    fn test_escape_address_property_never_holds_the_separator(
        address in any_address(),
    ) {
        prop_assume!(!needs_shortening(&address));

        let name = encode_clone_folder_name(&address);

        prop_assert!(split_shortened_name(&name).is_none(), "{name}");
    }

    #[test]
    fn test_escape_address_property_keeps_only_plain_characters(
        address in any_address(),
    ) {
        let name = encode_clone_folder_name(&address);
        let start = split_shortened_name(&name)
            .map_or(name.as_str(), |(start, _hash)| start);

        let is_plain = start.chars().all(|character| {
            character.is_ascii_lowercase()
                || character.is_ascii_digit()
                || character == '-'
                || character == ESCAPE_MARKER
        });
        prop_assert!(is_plain, "{start}");
    }

    #[test]
    fn test_escape_address_start_property_is_a_start_of_the_escaped_name(
        address in any_shortened_address(),
    ) {
        let (start, _hash) = shortened_parts(&address)?;

        prop_assert!(escape_like_today(&address).starts_with(&start));
    }

    #[test]
    fn test_escape_address_start_property_never_cuts_an_escape(
        address in any_shortened_address(),
    ) {
        let (start, _hash) = shortened_parts(&address)?;

        prop_assert!(has_whole_escapes_only(&start), "{start}");
    }

    #[test]
    fn test_escape_address_start_property_uses_the_room_it_has(
        address in any_shortened_address(),
    ) {
        let (start, _hash) = shortened_parts(&address)?;

        prop_assert!(start.len() <= SHORTENED_START_BYTES);
        prop_assert!(start.len() + ESCAPE_LENGTH > SHORTENED_START_BYTES);
    }

    #[test]
    fn test_hash_address_property_is_the_sha_256_of_the_whole_address(
        address in any_shortened_address(),
    ) {
        let (_start, hash) = shortened_parts(&address)?;

        prop_assert_eq!(hash, expected_hash(&address));
    }

    #[test]
    fn test_hash_address_property_is_lowercase_hexadecimal(
        address in any_shortened_address(),
    ) {
        let (_start, hash) = shortened_parts(&address)?;

        prop_assert_eq!(hash.len(), HASH_LENGTH);
        let is_hexadecimal =
            hash.chars().all(|character| character.is_ascii_hexdigit());
        let is_lowercase = hash.to_ascii_lowercase() == hash;
        prop_assert!(is_lowercase, "{hash}");
        prop_assert!(is_hexadecimal, "{hash}");
    }

    #[test]
    fn test_hash_address_property_case_variants_get_their_own_hash(
        address in any_shortened_address(),
    ) {
        let variant = address.to_lowercase();
        prop_assume!(variant != address && needs_shortening(&variant));

        let (_start, hash) = shortened_parts(&address)?;
        let (_variant_start, variant_hash) = shortened_parts(&variant)?;

        prop_assert_ne!(hash, variant_hash);
    }
}
