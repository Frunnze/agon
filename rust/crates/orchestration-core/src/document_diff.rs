use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DiffLine {
    Unchanged(String),
    Added(String),
    Removed(String),
}

type CommonLengthTable = Vec<Vec<usize>>;

#[must_use]
pub fn diff_lines(
    previous_document: &str,
    current_document: &str,
) -> Vec<DiffLine> {
    let previous_lines: Vec<&str> = previous_document.lines().collect();
    let current_lines: Vec<&str> = current_document.lines().collect();
    let common_lengths =
        measure_common_suffixes(&previous_lines, &current_lines);

    let mut diff = Vec::new();
    let mut previous_index = 0;
    let mut current_index = 0;
    while previous_index < previous_lines.len()
        && current_index < current_lines.len()
    {
        let previous_line = previous_lines[previous_index];
        let current_line = current_lines[current_index];
        if previous_line == current_line {
            diff.push(DiffLine::Unchanged(previous_line.to_owned()));
            previous_index += 1;
            current_index += 1;
        } else if common_lengths[previous_index + 1][current_index]
            >= common_lengths[previous_index][current_index + 1]
        {
            diff.push(DiffLine::Removed(previous_line.to_owned()));
            previous_index += 1;
        } else {
            diff.push(DiffLine::Added(current_line.to_owned()));
            current_index += 1;
        }
    }

    for line in &previous_lines[previous_index..] {
        diff.push(DiffLine::Removed((*line).to_owned()));
    }
    for line in &current_lines[current_index..] {
        diff.push(DiffLine::Added((*line).to_owned()));
    }
    diff
}

fn measure_common_suffixes(
    previous_lines: &[&str],
    current_lines: &[&str],
) -> CommonLengthTable {
    let mut lengths =
        vec![vec![0; current_lines.len() + 1]; previous_lines.len() + 1];
    for previous_index in (0..previous_lines.len()).rev() {
        for current_index in (0..current_lines.len()).rev() {
            let is_same_line =
                previous_lines[previous_index] == current_lines[current_index];
            let length_after_both =
                lengths[previous_index + 1][current_index + 1];
            let length_after_previous =
                lengths[previous_index + 1][current_index];
            let length_after_current =
                lengths[previous_index][current_index + 1];
            lengths[previous_index][current_index] = if is_same_line {
                length_after_both + 1
            } else {
                length_after_previous.max(length_after_current)
            };
        }
    }
    lengths
}
