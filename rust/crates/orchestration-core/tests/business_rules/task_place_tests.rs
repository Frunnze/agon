use orchestration_core::task::{Task, TaskPlace};
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::entity_strategies::{
    example_task, project_identifier, workspace_identifier,
};

const PROJECT_FIELD: &str = "project_id";
const WORKSPACE_FIELD: &str = "workspace_id";

fn task_place() -> impl Strategy<Value = TaskPlace> {
    prop_oneof![
        project_identifier()
            .prop_map(|project_id| TaskPlace::InProject { project_id }),
        workspace_identifier()
            .prop_map(|workspace_id| TaskPlace::InWorkspace { workspace_id }),
    ]
}

fn expected_place_field(place: TaskPlace) -> (&'static str, Value) {
    match place {
        TaskPlace::InProject { project_id } => {
            (PROJECT_FIELD, json!(project_id))
        }
        TaskPlace::InWorkspace { workspace_id } => {
            (WORKSPACE_FIELD, json!(workspace_id))
        }
    }
}

proptest! {
    #[test]
    fn test_task_place_property_round_trips_as_one_top_level_field(
        place in task_place(),
    ) {
        let task = Task { place, ..example_task() };

        let encoded = serde_json::to_value(&task)
            .map_err(|error| TestCaseError::fail(error.to_string()))?;
        let decoded: Task = serde_json::from_value(encoded.clone())
            .map_err(|error| TestCaseError::fail(error.to_string()))?;

        prop_assert_eq!(decoded, task);
        let (field, identifier) = expected_place_field(place);
        prop_assert_eq!(&encoded[field], &identifier);
        let has_project = encoded.get(PROJECT_FIELD).is_some();
        let has_workspace = encoded.get(WORKSPACE_FIELD).is_some();
        prop_assert!(has_project != has_workspace, "{}", encoded);
    }
}
