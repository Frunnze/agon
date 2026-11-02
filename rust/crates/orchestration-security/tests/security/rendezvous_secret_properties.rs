use orchestration_security::pairing::{
    PairingCode, RENDEZVOUS_SECRET_LENGTH, derive_rendezvous_secret,
};
use proptest::prelude::*;

const CANONICAL_CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{6}";
const CODE_GROUP_LENGTH: usize = 3;
const DERIVATION_CASES: u32 = 12;
const PINNED_CODE: &str = "4F7-K2Q";
const PINNED_SECRET: &str =
    "fd4bdad493ca76d5ebcbf9c53ba254201a7c4c9923a0733003dc28283ca9b676";

fn derive_hex(code_text: &str) -> Result<String, TestCaseError> {
    let code = PairingCode::parse(code_text)
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let secret = derive_rendezvous_secret(&code)
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    Ok(hex::encode(secret.as_slice()))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DERIVATION_CASES))]

    #[test]
    fn test_derive_rendezvous_secret_property_both_devices_derive_the_same(
        symbols in CANONICAL_CODE_PATTERN,
    ) {
        let (first_group, second_group) = symbols.split_at(CODE_GROUP_LENGTH);
        let typed = format!("{} {}", first_group.to_lowercase(), second_group);

        let starting_device = derive_hex(&symbols)?;
        let joining_device = derive_hex(&typed)?;

        prop_assert_eq!(starting_device.len(), RENDEZVOUS_SECRET_LENGTH * 2);
        prop_assert_eq!(starting_device, joining_device);
    }

    #[test]
    fn test_derive_rendezvous_secret_property_other_codes_give_other_keys(
        first in CANONICAL_CODE_PATTERN,
        second in CANONICAL_CODE_PATTERN,
    ) {
        prop_assume!(first != second);

        let first_secret = derive_hex(&first)?;
        let second_secret = derive_hex(&second)?;

        prop_assert_ne!(first_secret, second_secret);
    }
}

#[test]
fn test_derive_rendezvous_secret_property_the_derivation_never_changes() {
    let derived = derive_hex(PINNED_CODE);

    assert_eq!(
        derived.map_err(|error| error.to_string()),
        Ok(PINNED_SECRET.to_owned())
    );
}
