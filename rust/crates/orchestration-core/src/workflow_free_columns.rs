const ONE_COLUMN: f64 = 1.0;
const ONE_SLOT: usize = 1;

pub(crate) struct TakenBand {
    pub(crate) left_column: f64,
    pub(crate) width: f64,
}

pub(crate) fn list_free_columns(
    left_column: f64,
    width: f64,
    taken_bands: &[TakenBand],
) -> Vec<f64> {
    let mut free_columns = Vec::new();
    let mut column = left_column;
    while column < left_column + width {
        let is_taken = taken_bands.iter().any(|band| {
            band.left_column <= column
                && column < band.left_column + band.width
        });
        if !is_taken {
            free_columns.push(column);
        }
        column += ONE_COLUMN;
    }
    free_columns
}

pub(crate) fn pick_nearest_free_columns(
    wanted_columns: &[f64],
    free_columns: &[f64],
) -> Vec<f64> {
    let mut picked_columns = Vec::new();
    let mut first_candidate = 0;
    for (position, wanted_column) in wanted_columns.iter().enumerate() {
        let columns_still_wanted = wanted_columns.len() - position;
        let last_candidate = free_columns.len() - columns_still_wanted;

        let mut nearest = first_candidate;
        for candidate in first_candidate..=last_candidate {
            let distance = (free_columns[candidate] - wanted_column).abs();
            let nearest_distance =
                (free_columns[nearest] - wanted_column).abs();
            if distance < nearest_distance {
                nearest = candidate;
            }
        }
        picked_columns.push(free_columns[nearest]);
        first_candidate = nearest + ONE_SLOT;
    }
    picked_columns
}
