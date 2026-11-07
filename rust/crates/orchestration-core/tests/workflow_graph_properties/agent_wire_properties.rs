use orchestration_core::workflow::{CanvasPosition, StepKind, WorkflowAgent};
use proptest::prelude::*;
use serde_json::json;

use crate::document_reading::{
    agent_details, apply_details, document_workflow,
};
use crate::wire_reading::{list_keys, read_wire_part, without_fields};

const OPTIONAL_AGENT_FIELDS: [&str; 2] = ["step_kind", "approval_policy"];
const FIRST_WIRE_AGENT: usize = 0;
const HORIZONTAL_KEY: &str = "horizontal";
const VERTICAL_KEY: &str = "vertical";

fn finite_coordinate() -> impl Strategy<Value = f64> {
    any::<f64>()
        .prop_filter("coordinates are finite", |value| value.is_finite())
}

fn canvas_position() -> impl Strategy<Value = CanvasPosition> {
    (finite_coordinate(), finite_coordinate()).prop_map(
        |(horizontal, vertical)| CanvasPosition {
            horizontal,
            vertical,
        },
    )
}

fn workflow_agent() -> impl Strategy<Value = WorkflowAgent> {
    (
        document_workflow(),
        any::<prop::sample::Index>(),
        agent_details(),
        any::<String>(),
        canvas_position(),
    )
        .prop_map(|(workflow, pick, details, name, position)| {
            let picked = &workflow.agents[pick.index(workflow.agents.len())];
            WorkflowAgent {
                name,
                position,
                ..apply_details(picked, details)
            }
        })
}

proptest! {
    #[test]
    fn test_canvas_position_serialize_property_round_trips_bit_for_bit(
        position in canvas_position(),
    ) {
        let text = serde_json::to_string(&position)?;
        let read: CanvasPosition = serde_json::from_str(&text)?;

        let horizontal_bits = position.horizontal.to_bits();
        let vertical_bits = position.vertical.to_bits();
        prop_assert_eq!(read.horizontal.to_bits(), horizontal_bits);
        prop_assert_eq!(read.vertical.to_bits(), vertical_bits);
    }

    #[test]
    fn test_canvas_position_deserialize_property_needs_both_coordinates(
        coordinate in finite_coordinate(),
        is_horizontal_kept in any::<bool>(),
    ) {
        let kept_key = if is_horizontal_kept {
            HORIZONTAL_KEY
        } else {
            VERTICAL_KEY
        };
        let one_coordinate = json!({ kept_key: coordinate });

        let read: Result<CanvasPosition, _> =
            serde_json::from_value(one_coordinate);

        prop_assert!(read.is_err());
    }

    #[test]
    fn test_canvas_position_deserialize_property_refuses_text_coordinates(
        text in ".{0,6}",
        coordinate in finite_coordinate(),
    ) {
        let texty = json!({ HORIZONTAL_KEY: text, VERTICAL_KEY: coordinate });

        let read: Result<CanvasPosition, _> = serde_json::from_value(texty);

        prop_assert!(read.is_err());
    }

    #[test]
    fn test_workflow_agent_serialize_property_survives_a_json_round_trip(
        agent in workflow_agent(),
    ) {
        let text = serde_json::to_string(&agent)?;
        let read: WorkflowAgent = serde_json::from_str(&text)?;

        prop_assert_eq!(read, agent);
    }

    #[test]
    fn test_workflow_agent_deserialize_property_old_records_read_as_agents(
        agent in workflow_agent(),
    ) {
        let written = serde_json::to_value(&agent)?;
        let old_record = without_fields(&written, &OPTIONAL_AGENT_FIELDS);

        let read: WorkflowAgent = serde_json::from_value(old_record)?;

        let expected = WorkflowAgent {
            step_kind: StepKind::Agent,
            approval_policy: None,
            ..agent
        };
        prop_assert_eq!(read, expected);
    }

    #[test]
    fn test_workflow_agent_serialize_property_writes_the_shared_fields(
        agent in workflow_agent(),
    ) {
        let agent_pointer = format!("/agents/{FIRST_WIRE_AGENT}");
        let shared_agent = read_wire_part(&agent_pointer)?;

        let written = serde_json::to_value(&agent)?;

        prop_assert_eq!(list_keys(&written), list_keys(&shared_agent));
    }

}
