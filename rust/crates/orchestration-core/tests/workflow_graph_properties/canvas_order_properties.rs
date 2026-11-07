use orchestration_core::workflow::{CanvasPosition, StepKind, WorkflowAgent};
use orchestration_core::workflow_graph::agents_in_order;
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::canvas_reading::{
    canvas_position, compare_by_canvas, list_order_ids, repositioned,
};
use crate::routing_fixtures::routing_agent;
use crate::workflow_strategies::{arbitrary_workflow, workflow_from_parts};

const LARGEST_SHARED_PLACE_COUNT: usize = 6;
const SHARED_NAME: &str = "same";

fn shared_place_agents(
    names: Vec<String>,
    position: CanvasPosition,
) -> Vec<WorkflowAgent> {
    let mut agents = Vec::new();
    for (number, name) in (0_u128..).zip(names) {
        agents.push(WorkflowAgent {
            name,
            position,
            ..routing_agent(number, StepKind::Agent)
        });
    }
    agents
}

proptest! {
    #[test]
    fn test_compare_canvas_order_property_unconnected_agents_follow_the_key(
        workflow in arbitrary_workflow().prop_flat_map(repositioned),
    ) {
        let unconnected =
            workflow_from_parts(workflow.agents.clone(), Vec::new());

        let ordered = agents_in_order(&unconnected);

        let mut expected: Vec<&WorkflowAgent> =
            unconnected.agents.iter().collect();
        expected.sort_by(|first, second| compare_by_canvas(first, second));
        prop_assert_eq!(ordered, expected);
    }

    #[test]
    fn test_compare_canvas_order_property_one_place_falls_back_to_names(
        names in btree_set(".{0,4}", 1..=LARGEST_SHARED_PLACE_COUNT),
        position in canvas_position(),
    ) {
        let names: Vec<String> = names.into_iter().rev().collect();
        let agents = shared_place_agents(names.clone(), position);
        let workflow = workflow_from_parts(agents, Vec::new());

        let ordered: Vec<String> = agents_in_order(&workflow)
            .iter()
            .map(|agent| agent.name.clone())
            .collect();

        let mut sorted_names = names;
        sorted_names.sort();
        prop_assert_eq!(ordered, sorted_names);
    }

    #[test]
    fn test_compare_canvas_order_property_one_place_and_name_follow_ids(
        agent_count in 1..=LARGEST_SHARED_PLACE_COUNT,
        position in canvas_position(),
        storage_order in
            Just((0..LARGEST_SHARED_PLACE_COUNT).collect::<Vec<usize>>())
                .prop_shuffle(),
    ) {
        let names = vec![SHARED_NAME.to_owned(); agent_count];
        let agents = shared_place_agents(names, position);
        let mut shuffled = Vec::new();
        for position in storage_order {
            if let Some(agent) = agents.get(position) {
                shuffled.push(agent.clone());
            }
        }
        let workflow = workflow_from_parts(shuffled, Vec::new());

        let ordered = list_order_ids(&workflow);

        let mut sorted_ids = ordered.clone();
        sorted_ids.sort();
        prop_assert_eq!(ordered, sorted_ids);
    }
}
