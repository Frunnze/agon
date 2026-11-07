use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::dag_strategies::{forked_dag_workflow, wide_forked_dag_workflow};
use crate::layer_model::{expect_rows, list_distinct_rows, row_vertical};
use crate::layout_reading::is_same_coordinate;
use crate::routing_fixtures::connect;
use crate::workflow_strategies::workflow_from_parts;

const LARGEST_DANGLING_CONNECTIONS: usize = 5;
const LARGEST_DANGLING_NUMBER: u128 = 8;

fn any_layout_workflow() -> impl Strategy<Value = Workflow> {
    prop_oneof![forked_dag_workflow(), wide_forked_dag_workflow()]
}

fn workflow_without_steps() -> impl Strategy<Value = Workflow> {
    let pick = (0..LARGEST_DANGLING_NUMBER, 0..LARGEST_DANGLING_NUMBER);
    vec(pick, 0..=LARGEST_DANGLING_CONNECTIONS).prop_map(|picks| {
        let mut connections = Vec::new();
        for (from, to) in picks {
            connections.push(connect(from, to, None, None));
        }
        workflow_from_parts(Vec::new(), connections)
    })
}

fn deepest_allowed_vertical(workflow: &Workflow) -> f64 {
    let step_count = workflow.agents.len();
    row_vertical(step_count.saturating_sub(1))
}

proptest! {
    #[test]
    fn test_count_rows_property_rows_have_no_gaps(
        workflow in any_layout_workflow(),
    ) {
        let rows = list_distinct_rows(&lay_out_workflow(&workflow));

        for (row, vertical) in rows.iter().enumerate() {
            prop_assert!(is_same_coordinate(*vertical, row_vertical(row)));
        }
    }

    #[test]
    fn test_count_rows_property_a_workflow_without_steps_stays_empty(
        workflow in workflow_without_steps(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        prop_assert!(laid_out.agents.is_empty());
        prop_assert_eq!(laid_out.connections, workflow.connections);
    }

    #[test]
    fn test_count_rows_property_rows_never_outnumber_the_steps(
        workflow in any_layout_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let deepest_allowed = deepest_allowed_vertical(&workflow);

        for agent in &laid_out.agents {
            prop_assert!(
                agent.position.vertical <= deepest_allowed,
                "{} below {}",
                agent.position.vertical,
                deepest_allowed
            );
        }
    }

    #[test]
    fn test_list_row_verticals_property_rows_are_whole_pitches_apart(
        workflow in any_layout_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let step_count = workflow.agents.len();

        for agent in &laid_out.agents {
            let vertical = agent.position.vertical;
            let is_whole_row = (0..step_count)
                .any(|row| is_same_coordinate(vertical, row_vertical(row)));
            prop_assert!(is_whole_row, "{}", agent.position.vertical);
        }
    }

    #[test]
    fn test_list_row_verticals_property_the_top_row_is_at_zero(
        workflow in any_layout_workflow(),
    ) {
        let rows = list_distinct_rows(&lay_out_workflow(&workflow));

        prop_assert_eq!(rows.first().copied(), Some(row_vertical(0)));
    }

    #[test]
    fn test_list_row_verticals_property_deeper_steps_sit_lower(
        workflow in any_layout_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let expected_rows = expect_rows(&workflow);

        for first in &laid_out.agents {
            for second in &laid_out.agents {
                let is_deeper =
                    expected_rows[&first.id] < expected_rows[&second.id];
                if is_deeper {
                    prop_assert!(
                        first.position.vertical < second.position.vertical
                    );
                }
            }
        }
    }
}
