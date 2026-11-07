use std::cmp::Reverse;

use crate::workflow_fork_lanes::ForkLane;
use crate::workflow_layers::{ONE_LAYER, count_rows};
use crate::workflow_row_order::{RowItem, RowOrder};

const NO_COLUMNS: f64 = 0.0;
const ONE_COLUMN: f64 = 1.0;

pub(crate) struct ColumnPlan<'layout> {
    pub(crate) layers: &'layout [usize],
    pub(crate) row_order: RowOrder<'layout>,
    pub(crate) lanes: &'layout [ForkLane],
    pub(crate) step_lanes: Vec<Option<usize>>,
    pub(crate) fork_last_rows: Vec<Option<usize>>,
    pub(crate) lane_widths: Vec<f64>,
    pub(crate) canvas_width: f64,
}

pub(crate) fn split_row_items(
    items: Vec<RowItem>,
) -> (Vec<RowItem>, Vec<usize>) {
    let mut forks = Vec::new();
    let mut steps = Vec::new();
    for item in items {
        match item {
            RowItem::Step(step_index) => steps.push(step_index),
            RowItem::Fork(_) => forks.push(item),
        }
    }
    (forks, steps)
}

impl ColumnPlan<'_> {
    pub(crate) fn measure_widths(&mut self) {
        let mut inner_lanes_first: Vec<usize> =
            (0..self.lanes.len()).collect();
        inner_lanes_first.sort_by_key(|lane_index| {
            Reverse(self.layers[self.lanes[*lane_index].fork_index])
        });
        for lane_index in inner_lanes_first {
            let lane_width = self.measure_widest_row(Some(lane_index));
            self.lane_widths[lane_index] = lane_width;
        }
        self.canvas_width = self.measure_widest_row(None);
    }

    fn measure_widest_row(&self, container: Option<usize>) -> f64 {
        let mut widest_row_width = NO_COLUMNS;
        for row in 0..count_rows(self.layers) {
            let items = self.list_row_items(container, row);
            let (continuing_groups, _) =
                self.split_continuing_groups(items, row);
            if continuing_groups.is_empty() {
                let cluster_width = self.measure_cluster_width(container, row);
                widest_row_width = widest_row_width.max(cluster_width);
            }
        }
        widest_row_width
    }

    pub(crate) fn measure_cluster_width(
        &self,
        container: Option<usize>,
        first_row: usize,
    ) -> f64 {
        let first_items = self.list_row_items(container, first_row);
        let mut reserved_width = self.measure_items_width(&first_items);
        let mut cluster_width = reserved_width;
        let mut row = first_row + ONE_LAYER;
        loop {
            let items = self.list_row_items(container, row);
            let row_width = self.measure_items_width(&items);
            let (continuing_groups, new_items) =
                self.split_continuing_groups(items, row);
            if continuing_groups.is_empty() {
                return cluster_width;
            }

            let (new_forks, _) = split_row_items(new_items);
            reserved_width += self.measure_items_width(&new_forks);
            cluster_width = cluster_width.max(reserved_width).max(row_width);
            row += ONE_LAYER;
        }
    }

    fn measure_items_width(&self, items: &[RowItem]) -> f64 {
        let mut items_width = NO_COLUMNS;
        for item in items {
            items_width += self.measure_item_width(*item);
        }
        items_width
    }

    pub(crate) fn measure_item_width(&self, item: RowItem) -> f64 {
        let RowItem::Fork(fork_index) = item else {
            return ONE_COLUMN;
        };
        let mut fork_width = NO_COLUMNS;
        for lane_index in self.list_lanes_of_fork(fork_index) {
            fork_width += self.lane_widths[lane_index];
        }
        fork_width
    }

    pub(crate) fn list_lanes_of_fork(&self, fork_index: usize) -> Vec<usize> {
        let mut fork_lanes = Vec::new();
        for (lane_index, lane) in self.lanes.iter().enumerate() {
            if lane.fork_index == fork_index {
                fork_lanes.push(lane_index);
            }
        }
        fork_lanes
    }

    pub(crate) fn list_row_items(
        &self,
        container: Option<usize>,
        row: usize,
    ) -> Vec<RowItem> {
        let mut items = Vec::new();
        for (agent_index, step_lane) in self.step_lanes.iter().enumerate() {
            if *step_lane != container {
                continue;
            }
            if self.layers[agent_index] == row {
                items.push(RowItem::Step(agent_index));
            }
            let is_below_fork = self.layers[agent_index] < row;
            let last_lane_row = self.fork_last_rows[agent_index];
            let is_lane_row = last_lane_row.is_some_and(|last| row <= last);
            if is_below_fork && is_lane_row {
                items.push(RowItem::Fork(agent_index));
            }
        }
        items
    }

    pub(crate) fn split_continuing_groups(
        &self,
        items: Vec<RowItem>,
        row: usize,
    ) -> (Vec<RowItem>, Vec<RowItem>) {
        let mut continuing_groups = Vec::new();
        let mut new_items = Vec::new();
        for item in items {
            let is_continuing = match item {
                RowItem::Fork(fork_index) => {
                    self.layers[fork_index] + ONE_LAYER < row
                }
                RowItem::Step(_) => false,
            };
            if is_continuing {
                continuing_groups.push(item);
            } else {
                new_items.push(item);
            }
        }
        (continuing_groups, new_items)
    }
}
