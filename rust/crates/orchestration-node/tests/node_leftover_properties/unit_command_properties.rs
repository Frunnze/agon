use proptest::prelude::*;

use crate::support::command_strategies::arbitrary_json;
use crate::unit_command_checks::{
    AGENT_LOGIN_UNIT_COMMANDS, APPROVAL_UNIT_COMMANDS, DEVICE_UNIT_COMMANDS,
    PAIRING_UNIT_COMMANDS, RUN_UNIT_COMMANDS, SERVER_BACKUP_UNIT_COMMANDS,
    UNIT_COMMAND_CASES, check_bare_command_parses,
    check_refused_command_stays_local, check_stray_field_is_refused,
    stray_field_strategy, unit_command_strategy,
};

const MOST_REPEATS: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(UNIT_COMMAND_CASES))]

    #[test]
    fn test_agent_login_command_property_refuses_a_stray_field(
        name in unit_command_strategy(&AGENT_LOGIN_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_agent_login_command_property_the_bare_command_parses(
        name in unit_command_strategy(&AGENT_LOGIN_UNIT_COMMANDS),
        repeat_count in 1..=MOST_REPEATS,
    ) {
        check_bare_command_parses(name, repeat_count)?;
    }

    #[test]
    fn test_agent_login_command_property_a_refusal_stays_local(
        name in unit_command_strategy(&AGENT_LOGIN_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_refused_command_stays_local(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_approval_command_property_refuses_a_stray_field(
        name in unit_command_strategy(&APPROVAL_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_approval_command_property_the_bare_command_parses(
        name in unit_command_strategy(&APPROVAL_UNIT_COMMANDS),
        repeat_count in 1..=MOST_REPEATS,
    ) {
        check_bare_command_parses(name, repeat_count)?;
    }

    #[test]
    fn test_approval_command_property_a_refusal_stays_local(
        name in unit_command_strategy(&APPROVAL_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_refused_command_stays_local(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_device_command_property_refuses_a_stray_field(
        name in unit_command_strategy(&DEVICE_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_device_command_property_the_bare_command_parses(
        name in unit_command_strategy(&DEVICE_UNIT_COMMANDS),
        repeat_count in 1..=MOST_REPEATS,
    ) {
        check_bare_command_parses(name, repeat_count)?;
    }

    #[test]
    fn test_device_command_property_a_refusal_stays_local(
        name in unit_command_strategy(&DEVICE_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_refused_command_stays_local(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_pairing_command_property_refuses_a_stray_field(
        name in unit_command_strategy(&PAIRING_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_pairing_command_property_the_bare_command_parses(
        name in unit_command_strategy(&PAIRING_UNIT_COMMANDS),
        repeat_count in 1..=MOST_REPEATS,
    ) {
        check_bare_command_parses(name, repeat_count)?;
    }

    #[test]
    fn test_pairing_command_property_a_refusal_stays_local(
        name in unit_command_strategy(&PAIRING_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_refused_command_stays_local(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_run_command_property_refuses_a_stray_field(
        name in unit_command_strategy(&RUN_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_run_command_property_the_bare_command_parses(
        name in unit_command_strategy(&RUN_UNIT_COMMANDS),
        repeat_count in 1..=MOST_REPEATS,
    ) {
        check_bare_command_parses(name, repeat_count)?;
    }

    #[test]
    fn test_run_command_property_a_refusal_stays_local(
        name in unit_command_strategy(&RUN_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_refused_command_stays_local(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_server_backup_command_property_refuses_a_stray_field(
        name in unit_command_strategy(&SERVER_BACKUP_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(name, &stray_field, stray_value)?;
    }

    #[test]
    fn test_server_backup_command_property_the_bare_command_parses(
        name in unit_command_strategy(&SERVER_BACKUP_UNIT_COMMANDS),
        repeat_count in 1..=MOST_REPEATS,
    ) {
        check_bare_command_parses(name, repeat_count)?;
    }

    #[test]
    fn test_server_backup_command_property_a_refusal_stays_local(
        name in unit_command_strategy(&SERVER_BACKUP_UNIT_COMMANDS),
        stray_field in stray_field_strategy(),
        stray_value in arbitrary_json(),
    ) {
        check_refused_command_stays_local(name, &stray_field, stray_value)?;
    }
}
