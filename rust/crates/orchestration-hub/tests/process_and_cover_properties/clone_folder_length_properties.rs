use std::fs;

use orchestration_hub::cached_clones::{
    cached_clone_folder, decode_clone_folder_name, encode_clone_folder_name,
};
use proptest::prelude::*;

use crate::clone_name_support::{
    LONGEST_FOLDER_NAME_BYTES, any_address, any_long_address,
    escape_like_today,
};
use crate::target_folders::{create_target_folder, fail_with};

const CREATION_CASES: u32 = 32;

proptest! {
    #[test]
    fn test_encode_clone_folder_name_property_every_name_fits_the_limit(
        address in any_address(),
    ) {
        let name = encode_clone_folder_name(&address);

        let name_length = name.len();
        let fits = name_length <= LONGEST_FOLDER_NAME_BYTES;
        prop_assert!(fits, "{name_length}");
        prop_assert!(!name.is_empty() || address.is_empty());
        prop_assert!(!name.contains('/'));
    }

    #[test]
    fn test_encode_clone_folder_name_property_names_that_fit_stay_unchanged(
        address in any_address(),
    ) {
        let escaped = escape_like_today(&address);
        prop_assume!(escaped.len() <= LONGEST_FOLDER_NAME_BYTES);

        let name = encode_clone_folder_name(&address);

        prop_assert_eq!(&name, &escaped);
        prop_assert_eq!(decode_clone_folder_name(&name), Some(address));
    }

    #[test]
    fn test_encode_clone_folder_name_property_long_addresses_stay_apart(
        shared_start in any_long_address(),
        first_ending in "[a-zA-Z0-9_.]{1,3}",
        second_ending in "[a-zA-Z0-9_.]{1,3}",
    ) {
        let first_address = format!("{shared_start}{first_ending}");
        let second_address = format!("{shared_start}{second_ending}");

        let first_name = encode_clone_folder_name(&first_address);
        let second_name = encode_clone_folder_name(&second_address);

        let names_match = first_name == second_name;
        prop_assert_eq!(names_match, first_ending == second_ending);
        let encoded_again = encode_clone_folder_name(&first_address);
        prop_assert_eq!(&encoded_again, &first_name);
        let decoded = decode_clone_folder_name(&first_name);
        let is_never_another_address =
            decoded.is_none() || decoded.as_ref() == Some(&first_address);
        prop_assert!(is_never_another_address, "{decoded:?}");
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CREATION_CASES))]

    #[test]
    fn test_cached_clone_folder_property_long_addresses_can_be_created(
        address in any_long_address(),
    ) {
        let cache_root = create_target_folder()?;

        let folder = cached_clone_folder(cache_root.path(), &address);

        fs::create_dir(&folder).map_err(|problem| fail_with(&problem))?;
        prop_assert_eq!(folder.parent(), Some(cache_root.path()));
    }
}
