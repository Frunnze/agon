use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::dag_strategies::{
    FIRST_LANE_HEAD, GROUP_FORK, SIDE_ROOT, count_side_chain_steps,
    find_side_head,
};
use crate::layout_checks::{
    find_collision, find_group_overlap_violation, find_intruder_violation,
    find_lane_order_violation,
};
use crate::layout_reading::ONE_COLUMN;
use crate::pair_reading::{column_of, is_beside_in_order};
use crate::side_chain_families::{
    late_fork_family, list_chain, share_one_column, side_chain_family,
    two_side_chain_family,
};

struct ChainBeside {
    root: u128,
    steps: Vec<u128>,
}

fn list_group_steps(lane_length: u128) -> Vec<u128> {
    list_chain(FIRST_LANE_HEAD, lane_length + lane_length)
}

fn find_group_span(laid_out: &Workflow, lane_length: u128) -> (f64, f64) {
    let mut leftmost = f64::INFINITY;
    let mut rightmost = f64::NEG_INFINITY;
    for step in list_group_steps(lane_length) {
        leftmost = leftmost.min(column_of(laid_out, step));
        rightmost = rightmost.max(column_of(laid_out, step));
    }
    (leftmost, rightmost)
}

fn list_chains_beside(
    lane_length: u128,
    other_length: u128,
) -> [ChainBeside; 2] {
    let other_root = count_side_chain_steps(lane_length, lane_length);
    let other_steps =
        list_chain(other_root + 1, other_length.min(lane_length));
    [
        ChainBeside {
            root: SIDE_ROOT,
            steps: list_chain(find_side_head(lane_length), lane_length),
        },
        ChainBeside {
            root: other_root,
            steps: other_steps,
        },
    ]
}

fn is_on_the_side_of_its_root(
    laid_out: &Workflow,
    lane_length: u128,
    chain: &ChainBeside,
) -> bool {
    let (leftmost, rightmost) = find_group_span(laid_out, lane_length);
    let is_root_left =
        column_of(laid_out, chain.root) < column_of(laid_out, GROUP_FORK);
    chain.steps.iter().all(|step| {
        let column = column_of(laid_out, *step);
        if is_root_left {
            column + ONE_COLUMN <= leftmost
        } else {
            column >= rightmost + ONE_COLUMN
        }
    })
}

fn list_late_heads(lane_length: u128) -> (u128, u128) {
    let late_fork = find_side_head(lane_length);
    (late_fork + 1, late_fork + 2)
}

fn mixed_chain_workflow() -> impl Strategy<Value = Workflow> {
    prop_oneof![
        two_side_chain_family().prop_map(|(_, _, workflow)| workflow),
        late_fork_family().prop_map(|(_, workflow)| workflow),
    ]
}

proptest! {
    #[test]
    fn test_place_later_cluster_row_property_a_side_chain_keeps_its_column(
        (lane_length, side_length, workflow) in side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let rows_beside = side_length.min(lane_length);
        let side_steps = list_chain(find_side_head(lane_length), rows_beside);
        prop_assert!(share_one_column(&laid_out, &side_steps));
    }

    #[test]
    fn test_place_later_cluster_row_property_side_chains_keep_their_sides(
        (lane_length, other_length, workflow) in two_side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for chain in list_chains_beside(lane_length, other_length) {
            let is_on_side =
                is_on_the_side_of_its_root(&laid_out, lane_length, &chain);
            prop_assert!(is_on_side, "{:?}", chain.steps);
        }
    }

    #[test]
    fn test_place_later_cluster_row_property_group_rows_never_collide(
        workflow in mixed_chain_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_collision(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_list_group_bands_property_side_steps_never_land_on_a_lane(
        (_lane_length, _other_length, workflow) in two_side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_intruder_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_list_group_bands_property_a_late_group_keeps_apart(
        (_lane_length, workflow) in late_fork_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_group_overlap_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_list_group_bands_property_chain_lanes_follow_their_connections(
        workflow in mixed_chain_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_lane_order_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_split_row_items_property_a_late_group_opens_right_of_open_ones(
        (lane_length, workflow) in late_fork_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let (_, rightmost) = find_group_span(&laid_out, lane_length);
        let (first_head, second_head) = list_late_heads(lane_length);
        for late_head in [first_head, second_head] {
            let column = column_of(&laid_out, late_head);
            prop_assert!(column >= rightmost + ONE_COLUMN, "{column}");
        }
    }

    #[test]
    fn test_split_row_items_property_a_late_group_keeps_its_lane_order(
        (lane_length, workflow) in late_fork_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let late_fork = find_side_head(lane_length);
        let heads = list_late_heads(lane_length);
        prop_assert!(is_beside_in_order(&laid_out, late_fork, heads));
    }

    #[test]
    fn test_split_row_items_property_open_lanes_keep_their_columns(
        (lane_length, workflow) in late_fork_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let left_lane = list_chain(FIRST_LANE_HEAD, lane_length);
        let right_lane =
            list_chain(FIRST_LANE_HEAD + lane_length, lane_length);
        prop_assert!(share_one_column(&laid_out, &left_lane));
        prop_assert!(share_one_column(&laid_out, &right_lane));
    }
}
