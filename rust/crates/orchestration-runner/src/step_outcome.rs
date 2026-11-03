use thiserror::Error;

const OUTCOME_LABEL: &str = "outcome:";
const CHOICE_SEPARATOR: &str = ", ";

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum OutcomeProblem {
    #[error(
        "the step must end its final message with a line OUTCOME: <name>, \
         where <name> is one of: {}",
        .choices.join(CHOICE_SEPARATOR)
    )]
    Missing { choices: Vec<String> },
    #[error(
        "the step reported the outcome {reported:?}, which is not one of: {}",
        .choices.join(CHOICE_SEPARATOR)
    )]
    Unknown {
        reported: String,
        choices: Vec<String>,
    },
}

#[must_use]
pub fn compose_outcome_request(choices: &[String]) -> String {
    format!(
        "## Outcome\nEnd your final message with one line OUTCOME: <name>, \
         where <name> is one of: {}.",
        choices.join(CHOICE_SEPARATOR)
    )
}

pub fn read_reported_outcome(
    final_message: Option<&str>,
    choices: &[String],
) -> Result<String, OutcomeProblem> {
    let reported = final_message.and_then(find_last_outcome_line);
    let Some(reported) = reported else {
        return Err(OutcomeProblem::Missing {
            choices: choices.to_vec(),
        });
    };
    let normalized = reported.to_lowercase();
    let matching_choice = choices
        .iter()
        .find(|choice| choice.to_lowercase() == normalized);
    match matching_choice {
        Some(choice) => Ok(choice.clone()),
        None => Err(OutcomeProblem::Unknown {
            reported,
            choices: choices.to_vec(),
        }),
    }
}

fn find_last_outcome_line(final_message: &str) -> Option<String> {
    for line in final_message.lines().rev() {
        let trimmed_line = line.trim();
        let label_length = OUTCOME_LABEL.len();
        let Some(label) = trimmed_line.get(..label_length) else {
            continue;
        };
        if label.eq_ignore_ascii_case(OUTCOME_LABEL) {
            let reported = trimmed_line[label_length..].trim();
            return Some(reported.to_owned());
        }
    }
    None
}
