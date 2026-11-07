use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::dag_strategies::{
    FIRST_LANE_HEAD, GROUP_FORK, forked_dag_workflow, reported_example,
    shuffle_storage,
};
use crate::layout_checks::{
    find_bound_violation, find_collision, find_free_row_centre_violation,
    find_lane_order_violation, find_leaf_lane_centre_violation,
};
use crate::layout_reading::is_same_coordinate;
use crate::pair_reading::{column_of, is_beside_in_order};
use crate::side_chain_families::{list_chain, side_chain_family};

const REPORTED_FORK: u128 = 1;
const REPORTED_FIRST_HEAD: u128 = 5;
const REPORTED_SECOND_HEAD: u128 = 3;

proptest! {
    #[test]
    fn test_place_row_property_the_reported_example_keeps_lanes_apart(
        workflow in shuffle_storage(reported_example()),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let heads = (REPORTED_FIRST_HEAD, REPORTED_SECOND_HEAD);
        prop_assert!(is_beside_in_order(&laid_out, REPORTED_FORK, heads));
        let violation = find_lane_order_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_place_row_property_steps_of_a_row_never_collide(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_collision(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_place_row_property_free_rows_share_one_centre(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_free_row_centre_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_place_items_property_leaf_lanes_keep_one_centre(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_leaf_lane_centre_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_place_items_property_columns_stay_whole_or_half_on_the_canvas(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_bound_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_place_items_property_lanes_stay_side_by_side_in_every_row(
        (lane_length, _side_length, workflow) in side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let left_lane = list_chain(FIRST_LANE_HEAD, lane_length);
        let right_lane =
            list_chain(FIRST_LANE_HEAD + lane_length, lane_length);
        let heads = (left_lane[0], right_lane[0]);
        prop_assert!(is_beside_in_order(&laid_out, GROUP_FORK, heads));
        let head_gap =
            column_of(&laid_out, heads.1) - column_of(&laid_out, heads.0);
        for (left_step, right_step) in left_lane.iter().zip(&right_lane) {
            let gap = column_of(&laid_out, *right_step)
                - column_of(&laid_out, *left_step);
            prop_assert!(is_same_coordinate(gap, head_gap), "{gap}");
        }
    }
}
