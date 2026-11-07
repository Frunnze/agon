use std::collections::BTreeMap;

use crate::workflow_column_plan::{ColumnPlan, split_row_items};
use crate::workflow_fork_lanes::{ForkLane, find_lane_of_each_step};
use crate::workflow_free_columns::{
    TakenBand, list_free_columns, pick_nearest_free_columns,
};
use crate::workflow_layers::{ForwardLink, count_rows};
use crate::workflow_row_order::{RowItem, RowOrder};

const NO_COLUMNS: f64 = 0.0;
const LEFT_EDGE: f64 = 0.0;
const SIDES_OF_A_ROW: f64 = 2.0;

#[derive(Clone, Copy)]
struct ClusterFrame {
    left_column: f64,
    width: f64,
    next_group_column: f64,
}

struct PlacedColumns {
    step_columns: Vec<f64>,
    group_columns: Vec<f64>,
    cluster_frames: BTreeMap<Option<usize>, ClusterFrame>,
}

pub(crate) fn place_steps_in_columns(
    layers: &[usize],
    links: &[ForwardLink],
    lanes: &[ForkLane],
) -> Vec<f64> {
    let step_lanes = find_lane_of_each_step(lanes, layers);
    let fork_last_rows = list_fork_last_rows(layers, lanes, &step_lanes);
    let mut plan = ColumnPlan {
        layers,
        row_order: RowOrder { layers, links },
        lanes,
        step_lanes,
        fork_last_rows,
        lane_widths: vec![NO_COLUMNS; lanes.len()],
        canvas_width: NO_COLUMNS,
    };
    plan.measure_widths();

    let mut placed = PlacedColumns {
        step_columns: vec![LEFT_EDGE; layers.len()],
        group_columns: vec![LEFT_EDGE; layers.len()],
        cluster_frames: BTreeMap::new(),
    };
    for row in 0..count_rows(layers) {
        plan.place_row(None, row, LEFT_EDGE, &mut placed);
    }
    placed.step_columns
}

fn list_fork_last_rows(
    layers: &[usize],
    lanes: &[ForkLane],
    step_lanes: &[Option<usize>],
) -> Vec<Option<usize>> {
    let mut fork_last_rows = vec![None; layers.len()];
    for (step_index, row) in layers.iter().enumerate() {
        let mut container = step_lanes[step_index];
        while let Some(lane_index) = container {
            let fork_index = lanes[lane_index].fork_index;
            let last_row = fork_last_rows[fork_index].max(Some(*row));
            fork_last_rows[fork_index] = last_row;
            container = step_lanes[fork_index];
        }
    }
    fork_last_rows
}

impl ColumnPlan<'_> {
    fn place_row(
        &self,
        container: Option<usize>,
        row: usize,
        left_column: f64,
        placed: &mut PlacedColumns,
    ) {
        let items = self.list_row_items(container, row);
        let (continuing_groups, mut new_items) =
            self.split_continuing_groups(items, row);
        new_items.sort_by(|first, second| {
            self.row_order.compare_row_items(
                *first,
                *second,
                &placed.step_columns,
            )
        });
        if !continuing_groups.is_empty() {
            self.place_later_cluster_row(
                container,
                row,
                &continuing_groups,
                new_items,
                placed,
            );
            return;
        }

        let container_width = match container {
            Some(lane_index) => self.lane_widths[lane_index],
            None => self.canvas_width,
        };
        let cluster_width = self.measure_cluster_width(container, row);
        let free_width = container_width - cluster_width;
        let cluster_left = left_column + free_width / SIDES_OF_A_ROW;
        let next_group_column =
            self.place_items(&new_items, row, cluster_left, placed);
        let frame = ClusterFrame {
            left_column: cluster_left,
            width: cluster_width,
            next_group_column,
        };
        placed.cluster_frames.insert(container, frame);
    }

    fn place_later_cluster_row(
        &self,
        container: Option<usize>,
        row: usize,
        continuing_groups: &[RowItem],
        new_items: Vec<RowItem>,
        placed: &mut PlacedColumns,
    ) {
        let frame = placed.cluster_frames[&container];

        for group in continuing_groups {
            if let RowItem::Fork(fork_index) = *group {
                let group_column = placed.group_columns[fork_index];
                self.place_fork_lanes(fork_index, row, group_column, placed);
            }
        }

        let (new_forks, steps) = split_row_items(new_items);
        let next_group_column =
            self.place_items(&new_forks, row, frame.next_group_column, placed);
        let moved_frame = ClusterFrame {
            next_group_column,
            ..frame
        };
        placed.cluster_frames.insert(container, moved_frame);

        let mut open_groups = continuing_groups.to_vec();
        open_groups.extend(new_forks);
        self.place_steps_beside_groups(&steps, &open_groups, frame, placed);
    }

    fn place_steps_beside_groups(
        &self,
        steps: &[usize],
        open_groups: &[RowItem],
        frame: ClusterFrame,
        placed: &mut PlacedColumns,
    ) {
        let taken_bands = self.list_group_bands(open_groups, placed);
        let free_columns =
            list_free_columns(frame.left_column, frame.width, &taken_bands);

        let mut wanted_columns = Vec::new();
        for step_index in steps {
            let item = RowItem::Step(*step_index);
            let wanted_column = self
                .row_order
                .find_upstream_column(item, &placed.step_columns);
            wanted_columns.push(wanted_column);
        }

        let picked_columns =
            pick_nearest_free_columns(&wanted_columns, &free_columns);
        for (step_index, column) in steps.iter().zip(picked_columns) {
            placed.step_columns[*step_index] = column;
        }
    }

    fn list_group_bands(
        &self,
        groups: &[RowItem],
        placed: &PlacedColumns,
    ) -> Vec<TakenBand> {
        let mut group_bands = Vec::new();
        for group in groups {
            if let RowItem::Fork(fork_index) = *group {
                group_bands.push(TakenBand {
                    left_column: placed.group_columns[fork_index],
                    width: self.measure_item_width(*group),
                });
            }
        }
        group_bands
    }

    fn place_items(
        &self,
        items: &[RowItem],
        row: usize,
        left_column: f64,
        placed: &mut PlacedColumns,
    ) -> f64 {
        let mut column = left_column;
        for item in items {
            match *item {
                RowItem::Step(step_index) => {
                    placed.step_columns[step_index] = column;
                }
                RowItem::Fork(fork_index) => {
                    placed.group_columns[fork_index] = column;
                    self.place_fork_lanes(fork_index, row, column, placed);
                }
            }
            column += self.measure_item_width(*item);
        }
        column
    }

    fn place_fork_lanes(
        &self,
        fork_index: usize,
        row: usize,
        left_column: f64,
        placed: &mut PlacedColumns,
    ) {
        let mut lane_left_column = left_column;
        for lane_index in self.list_lanes_of_fork(fork_index) {
            self.place_row(Some(lane_index), row, lane_left_column, placed);
            lane_left_column += self.lane_widths[lane_index];
        }
    }
}
