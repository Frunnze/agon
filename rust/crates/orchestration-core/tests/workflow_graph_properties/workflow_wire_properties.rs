use orchestration_core::identifiers::{DeviceId, WorkflowAgentId};
use orchestration_core::workflow::{
    AgentConnection, Workflow, WorkflowSignature,
};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::Value;
use uuid::Uuid;

use crate::document_reading::document_workflow;
use crate::wire_reading::{
    list_keys, read_wire_cases, read_wire_part, without_fields,
};

const OPTIONAL_CONNECTION_FIELDS: [&str; 2] = ["condition", "round_limit"];
const LARGEST_SIGNATURE_LENGTH: usize = 70;
const FIRST_WIRE_CONNECTION: usize = 0;
const SIGNATURE_KEY: &str = "signature";

fn signature() -> impl Strategy<Value = WorkflowSignature> {
    (
        ".{0,8}",
        vec(any::<u8>(), 0..=LARGEST_SIGNATURE_LENGTH),
        any::<String>(),
    )
        .prop_map(|(signer, signature, signed_document)| {
            WorkflowSignature {
                signed_by: DeviceId(signer),
                signature,
                signed_document,
            }
        })
}

fn signed_or_not_workflow() -> impl Strategy<Value = Workflow> {
    (document_workflow(), proptest::option::of(signature())).prop_map(
        |(workflow, signature)| Workflow {
            signature,
            ..workflow
        },
    )
}

proptest! {
    #[test]
    fn test_agent_connection_serialize_property_survives_a_round_trip(
        from in any::<u128>(),
        to in any::<u128>(),
        condition in proptest::option::of(any::<String>()),
        round_limit in proptest::option::of(any::<u32>()),
    ) {
        let connection = AgentConnection {
            from: WorkflowAgentId(Uuid::from_u128(from)),
            to: WorkflowAgentId(Uuid::from_u128(to)),
            condition,
            round_limit,
        };

        let text = serde_json::to_string(&connection)?;
        let read: AgentConnection = serde_json::from_str(&text)?;

        prop_assert_eq!(read, connection);
    }

    #[test]
    fn test_agent_connection_deserialize_property_old_records_are_plain(
        from in any::<u128>(),
        to in any::<u128>(),
    ) {
        let connection = AgentConnection::plain(
            WorkflowAgentId(Uuid::from_u128(from)),
            WorkflowAgentId(Uuid::from_u128(to)),
        );
        let written = serde_json::to_value(&connection)?;
        let old_record = without_fields(&written, &OPTIONAL_CONNECTION_FIELDS);

        let read: AgentConnection = serde_json::from_value(old_record)?;

        prop_assert_eq!(read, connection);
    }

    #[test]
    fn test_agent_connection_serialize_property_writes_the_shared_fields(
        from in any::<u128>(),
        to in any::<u128>(),
    ) {
        let pointer = format!("/connections/{FIRST_WIRE_CONNECTION}");
        let shared = read_wire_part(&pointer)?;
        let connection = AgentConnection::plain(
            WorkflowAgentId(Uuid::from_u128(from)),
            WorkflowAgentId(Uuid::from_u128(to)),
        );

        let written = serde_json::to_value(&connection)?;

        prop_assert_eq!(list_keys(&written), list_keys(&shared));
    }

    #[test]
    fn test_workflow_signature_serialize_property_survives_a_round_trip(
        signature in signature(),
    ) {
        let text = serde_json::to_string(&signature)?;
        let read: WorkflowSignature = serde_json::from_str(&text)?;

        prop_assert_eq!(read, signature);
    }

    #[test]
    fn test_workflow_signature_serialize_property_writes_bytes_as_numbers(
        signature in signature(),
    ) {
        let shared = read_wire_part("/signature")?;

        let written = serde_json::to_value(&signature)?;

        let expected_bytes: Vec<Value> = signature
            .signature
            .iter()
            .map(|byte| Value::from(*byte))
            .collect();
        let expected = Value::Array(expected_bytes);
        prop_assert_eq!(written.get(SIGNATURE_KEY), Some(&expected));
        prop_assert_eq!(list_keys(&written), list_keys(&shared));
    }

    #[test]
    fn test_workflow_signature_deserialize_property_refuses_wide_bytes(
        signature in signature(),
        wide_byte in 256_u32..=u32::from(u16::MAX),
    ) {
        let mut written = serde_json::to_value(&signature)?;
        let bytes =
            written.get_mut(SIGNATURE_KEY).and_then(Value::as_array_mut);
        if let Some(bytes) = bytes {
            bytes.push(Value::from(wide_byte));
        }

        let read: Result<WorkflowSignature, _> =
            serde_json::from_value(written);

        prop_assert!(read.is_err());
    }

    #[test]
    fn test_workflow_serialize_property_survives_a_json_round_trip(
        workflow in signed_or_not_workflow(),
    ) {
        let text = serde_json::to_string(&workflow)?;
        let read: Workflow = serde_json::from_str(&text)?;

        prop_assert_eq!(read, workflow);
    }

    #[test]
    fn test_workflow_serialize_property_writes_the_shared_fields(
        workflow in signed_or_not_workflow(),
    ) {
        let shared = read_wire_cases()?.workflow;

        let written = serde_json::to_value(&workflow)?;

        prop_assert_eq!(list_keys(&written), list_keys(&shared));
        let is_null = written.get(SIGNATURE_KEY).is_some_and(Value::is_null);
        prop_assert_eq!(is_null, workflow.signature.is_none());
    }

    #[test]
    fn test_workflow_deserialize_property_reads_the_shared_workflow_back(
        position in any::<prop::sample::Index>(),
    ) {
        let shared = read_wire_cases()?.workflow;

        let read: Workflow = serde_json::from_value(shared.clone())?;
        let written = serde_json::to_value(&read)?;

        prop_assert_eq!(&written, &shared);
        let agent_position = position.index(read.agents.len());
        let agent_name = Value::from(read.agents[agent_position].name.clone());
        let pointer = format!("/agents/{agent_position}/name");
        prop_assert_eq!(shared.pointer(&pointer), Some(&agent_name));
    }
}
