use orchestration_core::workflow::Workflow;
use proptest::prelude::*;

use crate::dag_strategies::{
    late_fork_beside_group, shuffle_storage, side_chain_beside_group,
    two_side_chains_beside_group,
};
use crate::layout_reading::is_same_coordinate;
use crate::pair_reading::column_of;

const SMALLEST_LANE_LENGTH: u128 = 2;
const LARGEST_LANE_LENGTH: u128 = 4;
const SMALLEST_SIDE_LENGTH: u128 = 1;
const LARGEST_SIDE_LENGTH: u128 = 5;

pub type ChainFamily = (u128, u128, Workflow);

pub fn side_chain_family() -> impl Strategy<Value = ChainFamily> {
    (
        SMALLEST_LANE_LENGTH..=LARGEST_LANE_LENGTH,
        SMALLEST_SIDE_LENGTH..=LARGEST_SIDE_LENGTH,
    )
        .prop_flat_map(|(lane_length, side_length)| {
            let workflow = side_chain_beside_group(lane_length, side_length);
            (
                Just(lane_length),
                Just(side_length),
                shuffle_storage(workflow),
            )
        })
}

pub fn two_side_chain_family() -> impl Strategy<Value = ChainFamily> {
    (
        SMALLEST_LANE_LENGTH..=LARGEST_LANE_LENGTH,
        SMALLEST_SIDE_LENGTH..=LARGEST_SIDE_LENGTH,
    )
        .prop_flat_map(|(lane_length, other_length)| {
            let workflow =
                two_side_chains_beside_group(lane_length, other_length);
            (
                Just(lane_length),
                Just(other_length),
                shuffle_storage(workflow),
            )
        })
}

pub fn late_fork_family() -> impl Strategy<Value = (u128, Workflow)> {
    (SMALLEST_LANE_LENGTH..=LARGEST_LANE_LENGTH).prop_flat_map(|lane_length| {
        let workflow = late_fork_beside_group(lane_length);
        (Just(lane_length), shuffle_storage(workflow))
    })
}

pub fn list_chain(head: u128, length: u128) -> Vec<u128> {
    (head..head + length).collect()
}

pub fn share_one_column(laid_out: &Workflow, steps: &[u128]) -> bool {
    steps.windows(2).all(|neighbours| {
        let first = column_of(laid_out, neighbours[0]);
        let second = column_of(laid_out, neighbours[1]);
        is_same_coordinate(first, second)
    })
}
