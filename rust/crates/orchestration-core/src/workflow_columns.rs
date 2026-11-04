use std::cmp::{Ordering, Reverse};
use std::collections::BTreeSet;

use crate::workflow_fork_lanes::{ForkLane, find_lane_of_each_step};
use crate::workflow_layers::{ForwardLink, ONE_LAYER, count_rows};

const NO_COLUMNS: f64 = 0.0;
const ONE_COLUMN: f64 = 1.0;
const LEFT_EDGE: f64 = 0.0;
const NO_UPSTREAM_COLUMN: f64 = 0.0;
const NO_INPUTS: f64 = 0.0;
const ONE_INPUT: f64 = 1.0;
const SIDES_OF_A_ROW: f64 = 2.0;

#[derive(Clone, Copy)]
enum RowItem {
    Step(usize),
    Fork(usize),
}

struct ColumnPlan<'layout> {
    layers: &'layout [usize],
    links: &'layout [ForwardLink],
    lanes: &'layout [ForkLane],
    step_lanes: Vec<Option<usize>>,
    fork_last_rows: Vec<Option<usize>>,
    lane_widths: Vec<f64>,
    canvas_width: f64,
}

pub(crate) fn place_steps_in_columns(
    layers: &[usize],
    links: &[ForwardLink],
    lanes: &[ForkLane],
) -> Vec<f64> {
    let step_lanes = find_lane_of_each_step(lanes, layers.len());
    let fork_last_rows = list_fork_last_rows(layers, lanes, &step_lanes);
    let mut plan = ColumnPlan {
        layers,
        links,
        lanes,
        step_lanes,
        fork_last_rows,
        lane_widths: vec![NO_COLUMNS; lanes.len()],
        canvas_width: NO_COLUMNS,
    };
    plan.measure_widths();

    let mut columns = vec![LEFT_EDGE; layers.len()];
    for row in 0..count_rows(layers) {
        plan.place_row(None, row, LEFT_EDGE, &mut columns);
    }
    columns
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
    fn measure_widths(&mut self) {
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
            let row_width = self.measure_items_width(&items);
            widest_row_width = widest_row_width.max(row_width);
        }
        widest_row_width
    }

    fn measure_items_width(&self, items: &[RowItem]) -> f64 {
        let mut items_width = NO_COLUMNS;
        for item in items {
            items_width += self.measure_item_width(*item);
        }
        items_width
    }

    fn measure_item_width(&self, item: RowItem) -> f64 {
        let RowItem::Fork(fork_index) = item else {
            return ONE_COLUMN;
        };
        let mut fork_width = NO_COLUMNS;
        for lane_index in self.list_lanes_of_fork(fork_index) {
            fork_width += self.lane_widths[lane_index];
        }
        fork_width
    }

    fn list_lanes_of_fork(&self, fork_index: usize) -> Vec<usize> {
        let mut fork_lanes = Vec::new();
        for (lane_index, lane) in self.lanes.iter().enumerate() {
            if lane.fork_index == fork_index {
                fork_lanes.push(lane_index);
            }
        }
        fork_lanes
    }

    fn list_row_items(
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

    fn place_row(
        &self,
        container: Option<usize>,
        row: usize,
        left_column: f64,
        columns: &mut [f64],
    ) {
        let mut items = self.list_row_items(container, row);
        items.sort_by(|first, second| {
            self.compare_row_items(*first, *second, columns)
        });

        let container_width = match container {
            Some(lane_index) => self.lane_widths[lane_index],
            None => self.canvas_width,
        };
        let free_width = container_width - self.measure_items_width(&items);
        let mut column = left_column + free_width / SIDES_OF_A_ROW;
        for item in items {
            match item {
                RowItem::Step(step_index) => columns[step_index] = column,
                RowItem::Fork(fork_index) => {
                    self.place_fork_lanes(fork_index, row, column, columns);
                }
            }
            column += self.measure_item_width(item);
        }
    }

    fn place_fork_lanes(
        &self,
        fork_index: usize,
        row: usize,
        left_column: f64,
        columns: &mut [f64],
    ) {
        let mut lane_left_column = left_column;
        for lane_index in self.list_lanes_of_fork(fork_index) {
            self.place_row(Some(lane_index), row, lane_left_column, columns);
            lane_left_column += self.lane_widths[lane_index];
        }
    }

    fn compare_row_items(
        &self,
        first: RowItem,
        second: RowItem,
        columns: &[f64],
    ) -> Ordering {
        let first_column = self.find_upstream_column(first, columns);
        let second_column = self.find_upstream_column(second, columns);
        let column_order = first_column.total_cmp(&second_column);
        column_order
            .then(find_agent_index(first).cmp(&find_agent_index(second)))
    }

    fn find_upstream_column(&self, item: RowItem, columns: &[f64]) -> f64 {
        match item {
            RowItem::Step(step_index) => {
                self.find_average_input_column(step_index, columns)
            }
            RowItem::Fork(fork_index) => columns[fork_index],
        }
    }

    fn find_average_input_column(
        &self,
        step_index: usize,
        columns: &[f64],
    ) -> f64 {
        let mut inputs_in_row_above = BTreeSet::new();
        for link in self.links {
            let upstream_row = self.layers[link.upstream_index];
            let is_from_row_above =
                upstream_row + ONE_LAYER == self.layers[step_index];
            if link.downstream_index == step_index && is_from_row_above {
                inputs_in_row_above.insert(link.upstream_index);
            }
        }
        if inputs_in_row_above.is_empty() {
            return NO_UPSTREAM_COLUMN;
        }

        let mut column_total = NO_COLUMNS;
        let mut input_count = NO_INPUTS;
        for input_index in inputs_in_row_above {
            column_total += columns[input_index];
            input_count += ONE_INPUT;
        }
        column_total / input_count
    }
}

fn find_agent_index(item: RowItem) -> usize {
    match item {
        RowItem::Step(agent_index) | RowItem::Fork(agent_index) => agent_index,
    }
}
