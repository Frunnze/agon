use std::cmp::Ordering;
use std::collections::BTreeSet;

use crate::workflow_layers::{ForwardLink, ONE_LAYER};

const NO_COLUMNS: f64 = 0.0;
const NO_UPSTREAM_COLUMN: f64 = 0.0;
const NO_INPUTS: f64 = 0.0;
const ONE_INPUT: f64 = 1.0;

#[derive(Clone, Copy)]
pub(crate) enum RowItem {
    Step(usize),
    Fork(usize),
}

pub(crate) struct RowOrder<'layout> {
    pub(crate) layers: &'layout [usize],
    pub(crate) links: &'layout [ForwardLink],
}

impl RowOrder<'_> {
    pub(crate) fn compare_row_items(
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

    pub(crate) fn find_upstream_column(
        &self,
        item: RowItem,
        columns: &[f64],
    ) -> f64 {
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
