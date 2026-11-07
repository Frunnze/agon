use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::branching_strategies::shuffled_fork_workflow;
use crate::fork_reading::{
    find_first_fork, is_leaf_lane, list_fork_ids, list_lane_rows,
    measure_leaf_lane_width, read_column_of,
};
use crate::layout_reading::{
    StepIds, is_same_coordinate, list_branch_heads, list_lanes, list_rows,
    read_column,
};

const SIDES_OF_A_ROW: f64 = 2.0;

proptest! {
    #[test]
    fn test_list_row_items_property_steps_above_the_first_fork_line_up(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let Some(root_fork_id) = find_first_fork(&laid_out) else {
            return Ok(());
        };
        let root_column = read_column_of(&laid_out, root_fork_id);

        for row in list_rows(&laid_out) {
            prop_assert_eq!(row.len(), 1);
            prop_assert_eq!(Some(read_column(row[0])), root_column);
            if row[0].id == root_fork_id {
                break;
            }
        }
    }

    #[test]
    fn test_list_row_items_property_inner_forks_line_up_with_their_lane(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for inner_fork in &laid_out.agents {
            let mut narrowest_lane: Option<StepIds> = None;
            for fork_id in list_fork_ids(&laid_out) {
                for lane in list_lanes(&laid_out, fork_id) {
                    let is_narrower = narrowest_lane
                        .as_ref()
                        .is_none_or(|current| lane.len() < current.len());
                    if lane.contains(&inner_fork.id) && is_narrower {
                        narrowest_lane = Some(lane);
                    }
                }
            }
            let Some(lane) = narrowest_lane else {
                continue;
            };
            if list_branch_heads(&laid_out, inner_fork.id).is_empty() {
                continue;
            }
            for step in &laid_out.agents {
                let is_above =
                    step.position.vertical <= inner_fork.position.vertical;
                if lane.contains(&step.id) && is_above {
                    let same_column = is_same_coordinate(
                        read_column(step),
                        read_column(inner_fork),
                    );
                    prop_assert!(same_column);
                }
            }
        }
    }

    #[test]
    fn test_measure_items_width_property_a_fork_group_centres_on_its_fork(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            if !lanes.iter().all(|lane| is_leaf_lane(&laid_out, lane)) {
                continue;
            }
            let (Some(first_lane), Some(last_lane)) =
                (lanes.first(), lanes.last())
            else {
                continue;
            };
            let first_rows = list_lane_rows(&laid_out, first_lane);
            let last_rows = list_lane_rows(&laid_out, last_lane);
            let (Some(first_row), Some(last_row)) =
                (first_rows.first(), last_rows.first())
            else {
                continue;
            };
            let first_width = measure_leaf_lane_width(&first_rows);
            let last_width = measure_leaf_lane_width(&last_rows);
            let group_left =
                first_row.centre - (first_width - 1.0) / SIDES_OF_A_ROW;
            let group_right =
                last_row.centre + (last_width - 1.0) / SIDES_OF_A_ROW;
            let group_centre = (group_left + group_right) / SIDES_OF_A_ROW;
            let fork_column = read_column_of(&laid_out, fork_id);
            prop_assert_eq!(Some(group_centre), fork_column);
        }
    }
}
