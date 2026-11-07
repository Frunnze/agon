use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::dag_strategies::{
    FIRST_LANE_HEAD, forked_dag_workflow, reported_example, shuffle_storage,
};
use crate::layout_checks::{
    find_bound_violation, find_collision, find_free_row_centre_violation,
    find_left_edge_violation,
};
use crate::layout_reading::{ONE_COLUMN, is_same_coordinate, read_column};
use crate::side_chain_families::{
    list_chain, share_one_column, side_chain_family, two_side_chain_family,
};
use crate::tree_layout_table::read_tree_cases;

const SIDE_CHAIN_WIDTH: f64 = 3.0;
const TWO_SIDE_CHAINS_WIDTH: f64 = 4.0;

fn measure_used_width(laid_out: &Workflow) -> f64 {
    let mut leftmost = f64::INFINITY;
    let mut rightmost = f64::NEG_INFINITY;
    for agent in &laid_out.agents {
        leftmost = leftmost.min(read_column(agent));
        rightmost = rightmost.max(read_column(agent) + ONE_COLUMN);
    }
    rightmost - leftmost
}

#[test]
fn test_measure_cluster_width_property_trees_keep_their_recorded_layout()
-> Result<(), serde_json::Error> {
    for tree_case in read_tree_cases()? {
        let laid_out = lay_out_workflow(&tree_case.workflow);

        let mut positions = Vec::new();
        for agent in &laid_out.agents {
            positions.push(agent.position);
        }
        assert_eq!(positions, tree_case.positions);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_measure_cluster_width_property_columns_stay_within_the_agents(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_bound_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_measure_cluster_width_property_a_step_touches_the_left_edge(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_left_edge_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_measure_widest_row_property_a_side_chain_adds_one_column(
        (_lane_length, _side_length, workflow) in side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let used_width = measure_used_width(&laid_out);
        prop_assert!(is_same_coordinate(used_width, SIDE_CHAIN_WIDTH));
    }

    #[test]
    fn test_measure_widest_row_property_two_side_chains_add_two_columns(
        (_lane_length, _other_length, workflow) in two_side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let used_width = measure_used_width(&laid_out);
        prop_assert!(is_same_coordinate(used_width, TWO_SIDE_CHAINS_WIDTH));
    }

    #[test]
    fn test_split_continuing_groups_property_lanes_hold_their_columns(
        (lane_length, _side_length, workflow) in side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let left_lane = list_chain(FIRST_LANE_HEAD, lane_length);
        let right_lane =
            list_chain(FIRST_LANE_HEAD + lane_length, lane_length);
        prop_assert!(share_one_column(&laid_out, &left_lane));
        prop_assert!(share_one_column(&laid_out, &right_lane));
    }

    #[test]
    fn test_split_continuing_groups_property_rows_past_a_group_are_centred(
        (_lane_length, _side_length, workflow) in side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_free_row_centre_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_split_continuing_groups_property_the_example_fits_the_canvas(
        workflow in shuffle_storage(reported_example()),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let collision = find_collision(&laid_out);
        prop_assert!(collision.is_none(), "{collision:?}");
        let violation = find_bound_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }
}
