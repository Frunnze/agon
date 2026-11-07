use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::layout_reading::{
    LaidOutRow, ONE_COLUMN, drafted_workflow, drafted_workflow_without_forks,
    find_widest_row_size, hostile_workflow, is_same_coordinate, list_rows,
    measure_count, read_column,
};
use crate::routing_fixtures::{connect, routing_workflow};

const LEFT_EDGE: f64 = 0.0;
const SIDES_OF_A_ROW: f64 = 2.0;
const LARGEST_CHAIN_LENGTH: u128 = 8;
const LARGEST_ISOLATED_COUNT: u128 = 8;

fn chain_workflow(step_count: u128) -> Workflow {
    let mut connections = Vec::new();
    for number in 1..step_count {
        connections.push(connect(number - 1, number, None, None));
    }
    routing_workflow(step_count, connections)
}

fn find_centred_left_column(row_size: usize, widest_row_size: usize) -> f64 {
    let free_width = measure_count(widest_row_size) - measure_count(row_size);
    free_width / SIDES_OF_A_ROW
}

fn are_columns_packed(row: &LaidOutRow<'_>) -> bool {
    row.windows(2).all(|neighbours| {
        let gap = read_column(neighbours[1]) - read_column(neighbours[0]);
        is_same_coordinate(gap, ONE_COLUMN)
    })
}

fn is_row_centred(row: &LaidOutRow<'_>, widest_row_size: usize) -> bool {
    let (Some(leftmost), Some(rightmost)) = (row.first(), row.last()) else {
        return true;
    };
    let edges = read_column(leftmost) + read_column(rightmost);
    let canvas_edges = measure_count(widest_row_size) - ONE_COLUMN;
    is_same_coordinate(edges, canvas_edges)
}

proptest! {
    #[test]
    fn test_place_steps_in_columns_property_columns_stay_within_the_agents(
        workflow in prop_oneof![hostile_workflow(), drafted_workflow()],
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let agent_count = measure_count(laid_out.agents.len());
        for agent in &laid_out.agents {
            let column = read_column(agent);
            prop_assert!(column >= LEFT_EDGE, "{column}");
            prop_assert!(column + ONE_COLUMN <= agent_count, "{column}");
        }
    }

    #[test]
    fn test_place_steps_in_columns_property_a_chain_stays_in_one_column(
        step_count in 1..=LARGEST_CHAIN_LENGTH,
    ) {
        let laid_out = lay_out_workflow(&chain_workflow(step_count));

        for agent in &laid_out.agents {
            prop_assert!(is_same_coordinate(read_column(agent), LEFT_EDGE));
        }
    }

    #[test]
    fn test_place_steps_in_columns_property_isolated_steps_fill_one_row(
        step_count in 1..=LARGEST_ISOLATED_COUNT,
    ) {
        let laid_out = lay_out_workflow(&routing_workflow(step_count, vec![]));

        let mut expected_column = LEFT_EDGE;
        for agent in &laid_out.agents {
            prop_assert!(is_same_coordinate(agent.position.vertical, 0.0));
            let column = read_column(agent);
            prop_assert!(is_same_coordinate(column, expected_column));
            expected_column += ONE_COLUMN;
        }
    }

    #[test]
    fn test_place_row_property_fork_free_rows_match_the_centred_model(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let rows = list_rows(&laid_out);
        let widest_row_size = find_widest_row_size(&rows);
        for row in &rows {
            let mut expected_column =
                find_centred_left_column(row.len(), widest_row_size);
            for agent in row {
                let column = read_column(agent);
                prop_assert!(is_same_coordinate(column, expected_column));
                expected_column += ONE_COLUMN;
            }
        }
    }

    #[test]
    fn test_place_row_property_fork_free_rows_are_centred_on_the_widest(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let rows = list_rows(&laid_out);
        let widest_row_size = find_widest_row_size(&rows);
        for row in &rows {
            prop_assert!(is_row_centred(row, widest_row_size));
        }
    }

    #[test]
    fn test_place_row_property_columns_only_shift_by_half_columns(
        workflow in prop_oneof![hostile_workflow(), drafted_workflow()],
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for agent in &laid_out.agents {
            let doubled_column = read_column(agent) * SIDES_OF_A_ROW;
            prop_assert!(
                is_same_coordinate(doubled_column, doubled_column.round()),
                "{doubled_column}"
            );
        }
    }

    #[test]
    fn test_measure_items_width_property_fork_free_rows_have_no_gaps(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for row in &list_rows(&laid_out) {
            prop_assert!(are_columns_packed(row));
        }
    }

    #[test]
    fn test_measure_items_width_property_a_fork_free_row_spans_its_steps(
        workflow in drafted_workflow_without_forks(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for row in &list_rows(&laid_out) {
            let (Some(leftmost), Some(rightmost)) = (row.first(), row.last())
            else {
                continue;
            };
            let span = read_column(rightmost) - read_column(leftmost);
            let expected_span = measure_count(row.len()) - ONE_COLUMN;
            prop_assert!(is_same_coordinate(span, expected_span));
        }
    }

    #[test]
    fn test_measure_item_width_property_steps_of_a_row_are_a_column_apart(
        workflow in prop_oneof![hostile_workflow(), drafted_workflow()],
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for row in &list_rows(&laid_out) {
            for neighbours in row.windows(2) {
                let gap =
                    read_column(neighbours[1]) - read_column(neighbours[0]);
                prop_assert!(gap >= ONE_COLUMN, "{gap}");
            }
        }
    }
}
