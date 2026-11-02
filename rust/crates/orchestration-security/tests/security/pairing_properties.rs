use chrono::TimeDelta;
use orchestration_security::error::SecurityError;
use orchestration_security::pairing::{PairingCode, PairingSession};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::moment_strategy;

const CANONICAL_CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{6}";
const WRONG_LENGTH_CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{0,12}";
const CODE_LENGTH: usize = 6;
const CODE_GROUP_LENGTH: usize = 3;
const DECORATION_SLOTS: usize = CODE_LENGTH + 1;
const SESSION_LIFETIME_SECONDS: i64 = 300;
const LONGEST_TEST_WAIT_SECONDS: i64 = 1_000_000;
const FOREIGN_SYMBOLS: &[char] = &['U', 'u', '!', '@', '#', '_', '+', 'é'];

fn decoration_strategy() -> impl Strategy<Value = Vec<&'static str>> {
    vec(
        prop_oneof![Just(""), Just(" "), Just("-"), Just(" - ")],
        DECORATION_SLOTS,
    )
}

fn decorate_code(
    symbols: &str,
    decorations: &[&str],
    lowercase_choices: &[bool],
) -> String {
    let mut decorated = String::new();
    for (position, symbol) in symbols.chars().enumerate() {
        decorated.push_str(decorations[position]);
        if lowercase_choices[position] {
            decorated.push(symbol.to_ascii_lowercase());
        } else {
            decorated.push(symbol);
        }
    }
    decorated.push_str(decorations[CODE_LENGTH]);
    decorated
}

proptest! {
    #[test]
    fn test_generate_property_display_parses_back_to_same_code(
        _attempt in any::<u8>(),
    ) {
        let code = PairingCode::generate()?;

        let parsed = PairingCode::parse(&code.display())?;

        prop_assert_eq!(parsed, code);
    }

    #[test]
    fn test_parse_property_display_round_trips(
        symbols in CANONICAL_CODE_PATTERN,
    ) {
        let code = PairingCode::parse(&symbols)?;

        let reparsed = PairingCode::parse(&code.display())?;

        prop_assert_eq!(reparsed, code);
    }

    #[test]
    fn test_parse_property_ignores_case_spaces_and_dashes(
        symbols in CANONICAL_CODE_PATTERN,
        decorations in decoration_strategy(),
        lowercase_choices in vec(any::<bool>(), CODE_LENGTH),
    ) {
        let decorated =
            decorate_code(&symbols, &decorations, &lowercase_choices);

        let parsed = PairingCode::parse(&decorated)?;

        prop_assert_eq!(parsed, PairingCode::parse(&symbols)?);
    }

    #[test]
    fn test_parse_property_rejects_wrong_symbol_count(
        symbols in WRONG_LENGTH_CODE_PATTERN,
    ) {
        prop_assume!(symbols.len() != CODE_LENGTH);

        let parsed = PairingCode::parse(&symbols);

        prop_assert_eq!(parsed, Err(SecurityError::MalformedPairingCode));
    }

    #[test]
    fn test_parse_property_rejects_symbols_outside_crockford_alphabet(
        symbols in CANONICAL_CODE_PATTERN,
        position in 0..CODE_LENGTH,
        foreign_symbol in proptest::sample::select(FOREIGN_SYMBOLS),
    ) {
        let mut tampered: Vec<char> = symbols.chars().collect();
        tampered[position] = foreign_symbol;
        let tampered_text: String = tampered.into_iter().collect();

        let parsed = PairingCode::parse(&tampered_text);

        prop_assert_eq!(parsed, Err(SecurityError::MalformedPairingCode));
    }

    #[test]
    fn test_try_from_property_json_round_trip_keeps_code(
        symbols in CANONICAL_CODE_PATTERN,
    ) {
        let code = PairingCode::parse(&symbols)?;

        let json = serde_json::to_string(&code)
            .map_err(|error| TestCaseError::fail(error.to_string()))?;
        let restored: PairingCode = serde_json::from_str(&json)
            .map_err(|error| TestCaseError::fail(error.to_string()))?;

        prop_assert_eq!(json, format!("\"{symbols}\""));
        prop_assert_eq!(restored, code);
    }

    #[test]
    fn test_display_property_shows_two_groups_of_three(
        symbols in CANONICAL_CODE_PATTERN,
    ) {
        let code = PairingCode::parse(&symbols)?;

        let shown = code.display();

        let (first_group, second_group) = symbols.split_at(CODE_GROUP_LENGTH);
        prop_assert_eq!(shown, format!("{first_group}-{second_group}"));
    }

    #[test]
    fn test_start_property_session_accepts_its_code_for_five_minutes(
        started_at in moment_strategy(),
        elapsed_seconds in 0..SESSION_LIFETIME_SECONDS,
    ) {
        let session = PairingSession::start(started_at)?;
        let now = started_at + TimeDelta::seconds(elapsed_seconds);

        prop_assert_eq!(session.started_at, started_at);
        prop_assert!(!session.is_expired(now));
        prop_assert_eq!(session.verify_join(&session.code, now), Ok(()));
    }

    #[test]
    fn test_is_expired_property_expired_from_five_minutes_on(
        started_at in moment_strategy(),
        elapsed_seconds in SESSION_LIFETIME_SECONDS..LONGEST_TEST_WAIT_SECONDS,
    ) {
        let session = PairingSession::start(started_at)?;

        let now = started_at + TimeDelta::seconds(elapsed_seconds);

        prop_assert!(session.is_expired(now));
    }

    #[test]
    fn test_verify_join_property_rejects_expired_session(
        started_at in moment_strategy(),
        elapsed_seconds in SESSION_LIFETIME_SECONDS..LONGEST_TEST_WAIT_SECONDS,
    ) {
        let session = PairingSession::start(started_at)?;
        let now = started_at + TimeDelta::seconds(elapsed_seconds);

        let verification = session.verify_join(&session.code, now);

        let expected = Err(SecurityError::PairingSessionExpired);
        prop_assert_eq!(verification, expected);
    }

    #[test]
    fn test_verify_join_property_rejects_other_code(
        started_at in moment_strategy(),
        offered_symbols in CANONICAL_CODE_PATTERN,
    ) {
        let session = PairingSession::start(started_at)?;
        let offered_code = PairingCode::parse(&offered_symbols)?;
        prop_assume!(offered_code != session.code);

        let verification = session.verify_join(&offered_code, started_at);

        prop_assert_eq!(verification, Err(SecurityError::PairingCodeMismatch));
    }
}
