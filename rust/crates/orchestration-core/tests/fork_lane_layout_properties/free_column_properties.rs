use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::find_agent_by_id;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::dag_strategies::{
    FIRST_LANE_HEAD, count_side_chain_steps, find_side_head,
    wide_forked_dag_workflow,
};
use crate::layout_checks::{
    find_bound_violation, find_collision, find_free_row_centre_violation,
    find_group_overlap_violation, find_intruder_violation,
    find_lane_order_violation, find_leaf_lane_centre_violation,
    find_left_edge_violation, find_shared_step_violation,
    find_stranger_violation,
};
use crate::layout_reading::{is_same_coordinate, read_column};
use crate::pair_reading::column_of;
use crate::side_chain_families::{
    ChainFamily, list_chain, share_one_column, side_chain_family,
    two_side_chain_family,
};
use crate::workflow_strategies::agent_identifier;

const TOP_VERTICAL: f64 = 0.0;

fn any_side_chain_family() -> impl Strategy<Value = ChainFamily> {
    prop_oneof![side_chain_family(), two_side_chain_family()]
}

fn list_side_columns_in_group_rows(
    laid_out: &Workflow,
    lane_length: u128,
) -> Vec<f64> {
    let lane_steps = list_chain(FIRST_LANE_HEAD, lane_length + lane_length);
    let last_lane_step = agent_identifier(FIRST_LANE_HEAD + lane_length - 1);
    let last_group_vertical = find_agent_by_id(laid_out, last_lane_step)
        .map_or(f64::NEG_INFINITY, |step| step.position.vertical);

    let mut side_columns = Vec::new();
    for agent in &laid_out.agents {
        let vertical = agent.position.vertical;
        let is_group_row =
            vertical > TOP_VERTICAL && vertical <= last_group_vertical;
        let is_lane_step = lane_steps
            .iter()
            .any(|step| agent_identifier(*step) == agent.id);
        if is_group_row && !is_lane_step {
            side_columns.push(read_column(agent));
        }
    }
    side_columns
}

proptest! {
    #[test]
    fn test_list_free_columns_property_side_steps_sit_whole_columns_away(
        (lane_length, _side_length, workflow) in any_side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let lane_column = column_of(&laid_out, FIRST_LANE_HEAD);
        let side_columns =
            list_side_columns_in_group_rows(&laid_out, lane_length);
        prop_assert!(!side_columns.is_empty());
        for side_column in side_columns {
            let distance = side_column - lane_column;
            prop_assert!(is_same_coordinate(distance, distance.round()));
        }
    }

    #[test]
    fn test_list_free_columns_property_wide_groups_keep_strangers_out(
        workflow in wide_forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let stranger = find_stranger_violation(&laid_out);
        prop_assert!(stranger.is_none(), "{stranger:?}");
        let intruder = find_intruder_violation(&laid_out);
        prop_assert!(intruder.is_none(), "{intruder:?}");
    }

    #[test]
    fn test_list_free_columns_property_wide_rows_never_collide(
        workflow in wide_forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_collision(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_pick_nearest_free_columns_property_chains_keep_their_columns(
        (lane_length, other_length, workflow) in two_side_chain_family(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let chain = list_chain(find_side_head(lane_length), lane_length);
        prop_assert!(share_one_column(&laid_out, &chain));
        let other_root = count_side_chain_steps(lane_length, lane_length);
        let rows_beside = other_length.min(lane_length);
        let other_chain = list_chain(other_root + 1, rows_beside);
        prop_assert!(share_one_column(&laid_out, &other_chain));
    }

    #[test]
    fn test_pick_nearest_free_columns_property_wide_lanes_keep_their_order(
        workflow in wide_forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_lane_order_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_pick_nearest_free_columns_property_wide_layouts_fit_the_canvas(
        workflow in wide_forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let bound = find_bound_violation(&laid_out);
        prop_assert!(bound.is_none(), "{bound:?}");
        let left_edge = find_left_edge_violation(&laid_out);
        prop_assert!(left_edge.is_none(), "{left_edge:?}");
    }

    #[test]
    fn test_place_steps_beside_groups_property_wide_groups_keep_apart(
        workflow in wide_forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_group_overlap_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_place_steps_beside_groups_property_wide_leaf_lanes_stay_centred(
        workflow in wide_forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let violation = find_leaf_lane_centre_violation(&laid_out);
        prop_assert!(violation.is_none(), "{violation:?}");
    }

    #[test]
    fn test_place_steps_beside_groups_property_wide_shared_steps_stay_out(
        workflow in wide_forked_dag_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let shared = find_shared_step_violation(&laid_out);
        prop_assert!(shared.is_none(), "{shared:?}");
        let free_row = find_free_row_centre_violation(&laid_out);
        prop_assert!(free_row.is_none(), "{free_row:?}");
    }
}
