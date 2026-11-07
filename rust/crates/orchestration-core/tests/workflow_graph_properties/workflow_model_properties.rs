use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{
    AgentConnection, AgentKind, SignatureState, StepKind,
};
use proptest::prelude::*;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::entity_strategies::agent_kind;
use crate::wire_reading::read_wire_cases;

const AGENT_KIND_COUNT: usize = 3;
const SIGNATURE_STATE_COUNT: usize = 3;
const STEP_KIND_COUNT: usize = 2;
const MISSPELLINGS: [&str; 6] = [
    "",
    "ClaudeCode",
    "claude-code",
    "CLAUDE_CODE",
    "notSignedYet",
    " agent",
];

fn agent_id() -> impl Strategy<Value = WorkflowAgentId> {
    any::<u128>().prop_map(|number| WorkflowAgentId(Uuid::from_u128(number)))
}

fn step_kind() -> impl Strategy<Value = StepKind> {
    prop_oneof![Just(StepKind::Agent), Just(StepKind::Person)]
}

fn signature_state() -> impl Strategy<Value = SignatureState> {
    prop_oneof![
        Just(SignatureState::Signed),
        Just(SignatureState::NotSignedYet),
        Just(SignatureState::ChangedNotSigned),
    ]
}

fn connection() -> impl Strategy<Value = AgentConnection> {
    (
        agent_id(),
        agent_id(),
        proptest::option::of(".{0,8}"),
        proptest::option::of(any::<u32>()),
    )
        .prop_map(|(from, to, condition, round_limit)| AgentConnection {
            from,
            to,
            condition,
            round_limit,
        })
}

fn read_wire_name(value: &impl serde::Serialize) -> Option<String> {
    let json_value = serde_json::to_value(value).ok()?;
    json_value.as_str().map(str::to_owned)
}

proptest! {
    #[test]
    fn test_agent_connection_plain_property_keeps_both_ends(
        from in agent_id(),
        to in agent_id(),
    ) {
        let connection = AgentConnection::plain(from, to);

        prop_assert_eq!(connection.from, from);
        prop_assert_eq!(connection.to, to);
    }

    #[test]
    fn test_agent_connection_plain_property_has_no_outcome_and_no_rounds(
        from in agent_id(),
        to in agent_id(),
    ) {
        let connection = AgentConnection::plain(from, to);

        prop_assert!(!connection.is_loop());
        prop_assert_eq!(connection.condition, None);
        prop_assert_eq!(connection.round_limit, None);
    }

    #[test]
    fn test_agent_connection_plain_property_matches_json_with_only_ends(
        from in agent_id(),
        to in agent_id(),
    ) {
        let only_ends = json!({ "from": from.0, "to": to.0 });

        let read: Result<AgentConnection, _> =
            serde_json::from_value(only_ends);

        prop_assert_eq!(read.ok(), Some(AgentConnection::plain(from, to)));
    }

    #[test]
    fn test_agent_connection_is_loop_property_follows_the_round_limit(
        connection in connection(),
    ) {
        let has_round_limit = connection.round_limit.is_some();
        prop_assert_eq!(connection.is_loop(), has_round_limit);
    }

    #[test]
    fn test_agent_connection_is_loop_property_survives_a_json_round_trip(
        connection in connection(),
    ) {
        let text = serde_json::to_string(&connection)?;
        let read: AgentConnection = serde_json::from_str(&text)?;

        prop_assert_eq!(read.is_loop(), connection.is_loop());
        prop_assert_eq!(read, connection);
    }

    #[test]
    fn test_agent_connection_is_loop_property_ignores_the_outcome(
        connection in connection(),
        condition in proptest::option::of(".{0,8}"),
    ) {
        let reworded = AgentConnection {
            condition,
            ..connection.clone()
        };

        prop_assert_eq!(reworded.is_loop(), connection.is_loop());
    }

    #[test]
    fn test_agent_kind_serialize_property_survives_a_json_round_trip(
        kind in agent_kind(),
    ) {
        let text = serde_json::to_string(&kind)?;
        let read: AgentKind = serde_json::from_str(&text)?;

        prop_assert_eq!(read, kind);
    }

    #[test]
    fn test_agent_kind_serialize_property_uses_the_shared_wire_names(
        kind in agent_kind(),
    ) {
        let names = read_wire_cases()?.agent_kinds;

        let name = read_wire_name(&kind).unwrap_or_default();

        prop_assert!(names.contains(&name), "{name}");
    }

    #[test]
    fn test_agent_kind_deserialize_property_refuses_other_spellings(
        position in 0..MISSPELLINGS.len(),
    ) {
        let read: Result<AgentKind, _> =
            serde_json::from_value(Value::from(MISSPELLINGS[position]));

        prop_assert!(read.is_err());
    }

    #[test]
    fn test_step_kind_serialize_property_survives_a_json_round_trip(
        kind in step_kind(),
    ) {
        let text = serde_json::to_string(&kind)?;
        let read: StepKind = serde_json::from_str(&text)?;

        prop_assert_eq!(read, kind);
    }

    #[test]
    fn test_step_kind_default_property_is_an_agent_step(
        kind in step_kind(),
    ) {
        let names = read_wire_cases()?.step_kinds;

        prop_assert_eq!(StepKind::default(), StepKind::Agent);
        let name = read_wire_name(&kind).unwrap_or_default();
        prop_assert!(names.contains(&name), "{name}");
    }

    #[test]
    fn test_step_kind_deserialize_property_refuses_other_spellings(
        position in 0..MISSPELLINGS.len(),
    ) {
        let read: Result<StepKind, _> =
            serde_json::from_value(Value::from(MISSPELLINGS[position]));

        prop_assert!(read.is_err());
    }

    #[test]
    fn test_signature_state_serialize_property_survives_a_round_trip(
        state in signature_state(),
    ) {
        let text = serde_json::to_string(&state)?;
        let read: SignatureState = serde_json::from_str(&text)?;

        prop_assert_eq!(read, state);
    }

    #[test]
    fn test_signature_state_serialize_property_uses_the_shared_wire_names(
        state in signature_state(),
    ) {
        let names = read_wire_cases()?.signature_states;

        let name = read_wire_name(&state).unwrap_or_default();

        prop_assert!(names.contains(&name), "{name}");
    }

    #[test]
    fn test_signature_state_deserialize_property_refuses_other_spellings(
        position in 0..MISSPELLINGS.len(),
    ) {
        let read: Result<SignatureState, _> =
            serde_json::from_value(Value::from(MISSPELLINGS[position]));

        prop_assert!(read.is_err());
    }
}

#[test]
fn test_agent_kind_deserialize_property_reads_every_shared_name()
-> Result<(), serde_json::Error> {
    let cases = read_wire_cases()?;
    let mut read_kinds: Vec<AgentKind> = Vec::new();
    for name in cases.agent_kinds {
        let kind: AgentKind = serde_json::from_value(Value::from(name))?;
        assert!(!read_kinds.contains(&kind));
        read_kinds.push(kind);
    }
    let mut read_states: Vec<SignatureState> = Vec::new();
    for name in cases.signature_states {
        let state: SignatureState = serde_json::from_value(Value::from(name))?;
        assert!(!read_states.contains(&state));
        read_states.push(state);
    }
    let mut read_steps: Vec<StepKind> = Vec::new();
    for name in cases.step_kinds {
        let step: StepKind = serde_json::from_value(Value::from(name))?;
        assert!(!read_steps.contains(&step));
        read_steps.push(step);
    }
    assert_eq!(read_kinds.len(), AGENT_KIND_COUNT);
    assert_eq!(read_states.len(), SIGNATURE_STATE_COUNT);
    assert_eq!(read_steps.len(), STEP_KIND_COUNT);
    Ok(())
}
