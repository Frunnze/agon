use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::branching_strategies::shuffled_fork_workflow;
use crate::fork_reading::{
    are_lanes_apart, find_root_join, is_leaf_lane, list_fork_ids,
    list_lane_rows, measure_centre_distance, measure_leaf_lane_width,
    read_column_of,
};
use crate::layout_reading::{
    ONE_COLUMN, StepIds, drafted_workflow, find_row_index, hostile_workflow,
    is_same_coordinate, list_branch_heads, list_lanes, list_rows, read_column,
};

fn reverse_connections(workflow: &Workflow) -> Workflow {
    let mut connections = workflow.connections.clone();
    connections.reverse();
    Workflow {
        connections,
        ..workflow.clone()
    }
}

fn list_head_columns(workflow: &Workflow, heads: &[StepIds]) -> Vec<f64> {
    let mut columns = Vec::new();
    for lane in heads {
        for step_id in lane {
            if let Some(column) = read_column_of(workflow, *step_id) {
                columns.push(column);
            }
        }
    }
    columns
}

fn wrap_heads(workflow: &Workflow, fork_index: usize) -> Vec<StepIds> {
    let fork_id = workflow.agents[fork_index].id;
    let mut wrapped = Vec::new();
    for head in list_branch_heads(workflow, fork_id) {
        wrapped.push(StepIds::from([head]));
    }
    wrapped
}

proptest! {
    #[test]
    fn test_measure_widths_property_a_leaf_lane_keeps_one_centre(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            for lane in list_lanes(&laid_out, fork_id) {
                if !is_leaf_lane(&laid_out, &lane) {
                    continue;
                }
                let lane_rows = list_lane_rows(&laid_out, &lane);
                for neighbours in lane_rows.windows(2) {
                    let first = neighbours[0].centre;
                    let second = neighbours[1].centre;
                    prop_assert!(is_same_coordinate(first, second));
                }
            }
        }
    }

    #[test]
    fn test_measure_widths_property_leaf_lanes_sit_half_their_widths_apart(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            for neighbours in lanes.windows(2) {
                let (first, second) = (&neighbours[0], &neighbours[1]);
                if !is_leaf_lane(&laid_out, first)
                    || !is_leaf_lane(&laid_out, second)
                {
                    continue;
                }
                let first_rows = list_lane_rows(&laid_out, first);
                let second_rows = list_lane_rows(&laid_out, second);
                let (Some(first_row), Some(second_row)) =
                    (first_rows.first(), second_rows.first())
                else {
                    continue;
                };
                let distance = second_row.centre - first_row.centre;
                let expected_distance = measure_centre_distance(
                    measure_leaf_lane_width(&first_rows),
                    measure_leaf_lane_width(&second_rows),
                );
                prop_assert!(is_same_coordinate(distance, expected_distance));
            }
        }
    }

    #[test]
    fn test_measure_widths_property_a_lane_spans_no_more_than_its_steps(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            for lane in list_lanes(&laid_out, fork_id) {
                let columns = crate::layout_reading::list_columns_of(
                    &laid_out, &lane,
                );
                let Some((leftmost, rightmost)) =
                    crate::layout_reading::find_span(&columns)
                else {
                    continue;
                };
                let span = rightmost - leftmost + ONE_COLUMN;
                let step_count =
                    crate::layout_reading::measure_count(lane.len());
                prop_assert!(span <= step_count, "{span} > {step_count}");
            }
        }
    }

    #[test]
    fn test_place_fork_lanes_property_tree_lanes_keep_separate_bands(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            for i in 0..lanes.len() {
                for j in (i + 1)..lanes.len() {
                    let are_apart =
                        are_lanes_apart(&laid_out, &lanes[i], &lanes[j]);
                    prop_assert!(are_apart);
                }
            }
        }
    }

    #[test]
    fn test_place_fork_lanes_property_lanes_follow_connections_in_each_row(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let rows = list_rows(&laid_out);

        for fork_id in list_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            for row in &rows {
                let mut previous_rightmost = f64::NEG_INFINITY;
                for lane in &lanes {
                    let lane_columns: Vec<f64> = row
                        .iter()
                        .filter(|agent| lane.contains(&agent.id))
                        .map(|agent| read_column(agent))
                        .collect();
                    let Some((leftmost, rightmost)) =
                        crate::layout_reading::find_span(&lane_columns)
                    else {
                        continue;
                    };
                    prop_assert!(leftmost > previous_rightmost);
                    previous_rightmost = rightmost;
                }
            }
        }
    }

    #[test]
    fn test_place_fork_lanes_property_the_join_sits_under_its_fork(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let rows = list_rows(&laid_out);
        let Some(root_row) = rows.iter().find(|row| {
            !list_branch_heads(&laid_out, row[0].id).is_empty()
        }) else {
            return Ok(());
        };
        let root_fork_id = root_row[0].id;
        let Some(join_id) = find_root_join(&laid_out, root_fork_id) else {
            return Ok(());
        };

        let fork_column = read_column_of(&laid_out, root_fork_id);
        let join_column = read_column_of(&laid_out, join_id);
        prop_assert_eq!(fork_column, join_column);
    }

    #[test]
    fn test_list_lanes_of_fork_property_heads_follow_connection_order(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_index in 0..laid_out.agents.len() {
            let heads = wrap_heads(&laid_out, fork_index);
            let columns = list_head_columns(&laid_out, &heads);
            for neighbours in columns.windows(2) {
                prop_assert!(neighbours[0] < neighbours[1]);
            }
        }
    }

    #[test]
    fn test_list_lanes_of_fork_property_reversed_branches_reverse_lanes(
        workflow in shuffled_fork_workflow(),
    ) {
        let reversed = reverse_connections(&workflow);
        let laid_out = lay_out_workflow(&workflow);
        let reversed_layout = lay_out_workflow(&reversed);

        for fork_index in 0..laid_out.agents.len() {
            let heads = wrap_heads(&laid_out, fork_index);
            let mut reversed_heads = wrap_heads(&reversed_layout, fork_index);
            reversed_heads.reverse();
            prop_assert_eq!(&heads, &reversed_heads);
            let columns = list_head_columns(&laid_out, &heads);
            let reversed_columns =
                list_head_columns(&reversed_layout, &reversed_heads);
            for neighbours in reversed_columns.windows(2) {
                prop_assert!(neighbours[0] > neighbours[1]);
            }
            prop_assert_eq!(columns.len(), reversed_columns.len());
        }
    }

    #[test]
    fn test_list_row_items_property_every_step_is_placed_exactly_once(
        workflow in prop_oneof![hostile_workflow(), drafted_workflow()],
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let rows = list_rows(&laid_out);

        let agents = &laid_out.agents;
        for i in 0..agents.len() {
            prop_assert!(find_row_index(&rows, agents[i].id).is_some());
            for j in (i + 1)..agents.len() {
                prop_assert_ne!(agents[i].position, agents[j].position);
            }
        }
    }
}
