use std::collections::BTreeSet;
use std::fmt::Debug;

use orchestration_core::identifiers::{
    ApprovalId, DeviceId, ProjectId, RuleId, RunId, SkillId, TaskId,
    WorkflowAgentId, WorkflowId, WorkspaceId, generate_uuid,
};
use proptest::prelude::*;
use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::Value;
use uuid::{Uuid, Variant, Version};

const GENERATED_COUNT: usize = 64;

fn check_bare_text<Identifier>(
    identifier: &Identifier,
    expected_text: &str,
) -> Result<(), TestCaseError>
where
    Identifier: Serialize + DeserializeOwned + PartialEq + Debug,
{
    let encoded = serde_json::to_value(identifier)
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let decoded: Identifier = serde_json::from_value(encoded.clone())
        .map_err(|error| TestCaseError::fail(error.to_string()))?;

    prop_assert_eq!(encoded, Value::String(expected_text.to_owned()));
    prop_assert_eq!(&decoded, identifier);
    Ok(())
}

fn check_every_uuid_identifier(uuid: Uuid) -> Result<(), TestCaseError> {
    let text = uuid.to_string();
    check_bare_text(&WorkspaceId(uuid), &text)?;
    check_bare_text(&ProjectId(uuid), &text)?;
    check_bare_text(&WorkflowId(uuid), &text)?;
    check_bare_text(&WorkflowAgentId(uuid), &text)?;
    check_bare_text(&SkillId(uuid), &text)?;
    check_bare_text(&RuleId(uuid), &text)?;
    check_bare_text(&TaskId(uuid), &text)?;
    check_bare_text(&RunId(uuid), &text)?;
    check_bare_text(&ApprovalId(uuid), &text)
}

proptest! {
    #[test]
    fn test_generate_uuid_property_gives_random_version_four_uuids(
        _attempt in 0..4_u8,
    ) {
        let uuid = generate_uuid();

        prop_assert_eq!(uuid.get_version(), Some(Version::Random));
        prop_assert_eq!(uuid.get_variant(), Variant::RFC4122);
    }

    #[test]
    fn test_generate_uuid_property_never_repeats(_attempt in 0..4_u8) {
        let mut generated: BTreeSet<Uuid> = BTreeSet::new();
        for _ in 0..GENERATED_COUNT {
            generated.insert(generate_uuid());
        }

        prop_assert_eq!(generated.len(), GENERATED_COUNT);
    }

    #[test]
    fn test_generate_uuid_property_is_never_nil_and_reads_back(
        _attempt in 0..4_u8,
    ) {
        let uuid = generate_uuid();

        let read_back = Uuid::parse_str(&uuid.to_string());

        prop_assert!(!uuid.is_nil());
        prop_assert_eq!(read_back.ok(), Some(uuid));
    }

    #[test]
    fn test_identifiers_serde_property_write_the_bare_uuid_text(
        number in any::<u128>(),
    ) {
        check_every_uuid_identifier(Uuid::from_u128(number))?;
    }

    #[test]
    fn test_identifiers_ordering_property_follows_the_uuid_order(
        first in any::<u128>(),
        second in any::<u128>(),
    ) {
        let first_uuid = Uuid::from_u128(first);
        let second_uuid = Uuid::from_u128(second);
        let uuid_order = first_uuid.cmp(&second_uuid);

        prop_assert_eq!(
            WorkspaceId(first_uuid).cmp(&WorkspaceId(second_uuid)),
            uuid_order
        );
        prop_assert_eq!(
            RunId(first_uuid).cmp(&RunId(second_uuid)),
            uuid_order
        );
        prop_assert_eq!(
            WorkflowAgentId(first_uuid).cmp(&WorkflowAgentId(second_uuid)),
            uuid_order
        );
    }

    #[test]
    fn test_device_id_serde_property_writes_the_bare_text(text in ".*") {
        check_bare_text(&DeviceId(text.clone()), &text)?;
    }
}
