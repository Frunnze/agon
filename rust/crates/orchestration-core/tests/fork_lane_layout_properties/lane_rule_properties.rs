use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::validate_workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::branching_strategies::shuffled_fork_workflow;
use crate::dag_strategies::{
    forked_dag_workflow, forks_sharing_a_head, outer_join_through_inner_lane,
    shuffle_storage, smaller_lane_beside_a_wider_one,
};
use crate::lane_model::list_held_lanes;
use crate::layout_checks::{
    find_group_overlap_violation, find_intruder_violation,
    find_lane_order_violation, find_shared_step_violation,
    find_stranger_violation,
};
use crate::layout_reading::is_same_coordinate;
use crate::pair_reading::{
    column_of, find_listed_position, is_beside_in_order,
};

const FIRST_FORK: u128 = 0;
const SECOND_FORK: u128 = 1;
const SHARED_HEAD: u128 = 2;
const FIRST_FORK_OWN_HEAD: u128 = 3;
const SECOND_FORK_OWN_HEAD: u128 = 4;
const OUTER_JOIN: u128 = 5;
const SMALL_LANE_STEP: u128 = 4;
const SMALL_LANE_SIBLING: u128 = 5;

fn list_unheld_reached_steps(laid_out: &Workflow) -> Vec<WorkflowAgentId> {
    let mut unheld_steps = Vec::new();
    for held_lane in list_held_lanes(laid_out) {
        for step_id in held_lane.members.difference(&held_lane.reached_steps) {
            unheld_steps.push(*step_id);
        }
    }
    unheld_steps
}

proptest! {
    #[test]
    fn test_find_lane_of_each_step_property_unnested_groups_keep_apart(
        workflow in forked_dag_workflow(),
    ) {
        prop_assert!(validate_workflow(&workflow).is_ok());

        let laid_out = lay_out_workflow(&workflow);

        let violation = find_group_overlap_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_find_lane_of_each_step_property_lanes_follow_their_connections(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_lane_order_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_find_lane_of_each_step_property_tree_lanes_hold_their_reach(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for held_lane in list_held_lanes(&laid_out) {
            prop_assert_eq!(&held_lane.members, &held_lane.reached_steps);
        }
        let violation = find_intruder_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_find_innermost_lane_property_a_shared_head_joins_the_first_fork(
        workflow in shuffle_storage(forks_sharing_a_head()),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let is_first_listed = find_listed_position(&laid_out, FIRST_FORK)
            < find_listed_position(&laid_out, SECOND_FORK);
        let (holder, own_head) = if is_first_listed {
            (FIRST_FORK, FIRST_FORK_OWN_HEAD)
        } else {
            (SECOND_FORK, SECOND_FORK_OWN_HEAD)
        };
        let pair = (SHARED_HEAD, own_head);
        prop_assert!(is_beside_in_order(&laid_out, holder, pair));
        let violation = find_intruder_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_find_innermost_lane_property_the_smaller_lane_holds_the_step(
        workflow in shuffle_storage(smaller_lane_beside_a_wider_one()),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let pair = (SMALL_LANE_STEP, SMALL_LANE_SIBLING);
        prop_assert!(is_beside_in_order(&laid_out, SECOND_FORK, pair));
        let violation = find_lane_order_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_find_innermost_lane_property_groups_hold_only_their_members(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_intruder_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_is_inside_lanes_holding_fork_property_outer_joins_leave(
        workflow in shuffle_storage(outer_join_through_inner_lane()),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let join_column = column_of(&laid_out, OUTER_JOIN);
        let fork_column = column_of(&laid_out, FIRST_FORK);
        prop_assert!(is_same_coordinate(join_column, fork_column));
        let violation = find_shared_step_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_is_inside_lanes_holding_fork_property_shared_steps_stay_out(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        prop_assert!(list_unheld_reached_steps(&laid_out).is_empty());
        let violation = find_shared_step_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_is_inside_lanes_holding_fork_property_no_stranger_in_a_group(
        workflow in forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_stranger_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }
}
