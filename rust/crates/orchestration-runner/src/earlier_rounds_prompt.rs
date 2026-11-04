use orchestration_core::run::{EarlierStepRound, StepStatus};

const EARLIER_ROUNDS_HEADING: &str = "## This step's earlier rounds";
const ROUND_HEADING_PREFIX: &str = "### Round ";
const OUTCOME_PREFIX: &str = "Outcome: ";
const SKIPPED_ROUND_NOTE: &str = "This round was skipped.";
const ENTRY_SEPARATOR: &str = "\n\n";
const LINE_SEPARATOR: &str = "\n";
const FIRST_ROUND_NUMBER: usize = 1;
const ROUNDS_BEFORE_ANY_LOOP: u32 = 1;

#[must_use]
pub fn describe_earlier_rounds(
    earlier_rounds: &[EarlierStepRound],
    loop_round_limit: Option<u32>,
) -> Option<String> {
    if earlier_rounds.is_empty() {
        return None;
    }

    let current_round = earlier_rounds.len() + FIRST_ROUND_NUMBER;
    let round_sentence =
        describe_current_round(current_round, loop_round_limit);
    let opening = [EARLIER_ROUNDS_HEADING, &round_sentence];
    let mut entries = vec![opening.join(LINE_SEPARATOR)];
    for (index, earlier_round) in earlier_rounds.iter().enumerate() {
        let round_number = index + FIRST_ROUND_NUMBER;
        entries.push(describe_earlier_round(round_number, earlier_round));
    }
    Some(entries.join(ENTRY_SEPARATOR))
}

fn describe_current_round(
    current_round: usize,
    loop_round_limit: Option<u32>,
) -> String {
    let Some(round_limit) = loop_round_limit else {
        return format!("This is round {current_round} of this step.");
    };
    let round_count = round_limit.saturating_add(ROUNDS_BEFORE_ANY_LOOP);
    format!("This is round {current_round} of {round_count} of this step.")
}

fn describe_earlier_round(
    round_number: usize,
    earlier_round: &EarlierStepRound,
) -> String {
    let mut lines = vec![format!("{ROUND_HEADING_PREFIX}{round_number}")];
    if earlier_round.status == StepStatus::Skipped {
        lines.push(SKIPPED_ROUND_NOTE.to_owned());
    }
    if let Some(outcome) = &earlier_round.outcome {
        lines.push(format!("{OUTCOME_PREFIX}{outcome}"));
    }
    if let Some(result) = &earlier_round.result {
        lines.push(result.clone());
    }
    lines.join(LINE_SEPARATOR)
}
