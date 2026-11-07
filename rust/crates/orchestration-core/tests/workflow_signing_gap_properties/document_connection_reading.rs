use std::collections::BTreeSet;

use crate::document_reading::{
    OUTCOMES_PREFIX, STEP_START, find_value, list_step_blocks,
};
use crate::signing_gap_support::NamedConnection;

const AFTER_PREFIX: &str = "    after: ";
const EMPTY_LIST_TEXT: &str = "[]";
const OUTCOME_ARROW: &str = " -> ";
const ROUND_LIMIT_OPENING: &str = ", at most ";
const ROUND_LIMIT_CLOSING: &str = " rounds";
const LIST_OPENING: char = '[';
const LIST_CLOSING: char = ']';
const ITEM_SEPARATOR: char = ',';
const QUOTE: char = '"';

struct ReadStep {
    name: String,
    upstream_names: Vec<String>,
    outcomes: Vec<NamedConnection>,
}

pub fn read_document_connections(document: &str) -> BTreeSet<NamedConnection> {
    let mut steps = Vec::new();
    for block in list_step_blocks(document) {
        steps.push(read_step(&block));
    }

    let mut connections = BTreeSet::new();
    for step in &steps {
        connections.extend(step.outcomes.iter().cloned());
    }

    for step in &steps {
        for upstream_name in &step.upstream_names {
            let is_conditional_forward =
                step_outcomes_reach(&steps, upstream_name, &step.name);
            if !is_conditional_forward {
                let plain_connection =
                    (upstream_name.clone(), step.name.clone(), None, None);
                connections.insert(plain_connection);
            }
        }
    }
    connections
}

fn step_outcomes_reach(
    steps: &[ReadStep],
    source_name: &str,
    target_name: &str,
) -> bool {
    steps
        .iter()
        .filter(|step| step.name == source_name)
        .flat_map(|step| &step.outcomes)
        .any(|(_, target, _, round_limit)| {
            target == target_name && round_limit.is_none()
        })
}

fn read_step(block: &[&str]) -> ReadStep {
    let name_text = block
        .first()
        .and_then(|line| line.strip_prefix(STEP_START))
        .unwrap_or_default();
    let name = unquote(name_text);
    let after_text =
        find_value(block, AFTER_PREFIX).unwrap_or(EMPTY_LIST_TEXT);
    let outcomes_text =
        find_value(block, OUTCOMES_PREFIX).unwrap_or(EMPTY_LIST_TEXT);

    let mut outcomes = Vec::new();
    for outcome_text in split_list_items(outcomes_text) {
        outcomes.push(read_outcome(&name, &outcome_text));
    }
    ReadStep {
        upstream_names: split_list_items(after_text),
        outcomes,
        name,
    }
}

fn read_outcome(source_name: &str, outcome_text: &str) -> NamedConnection {
    let (condition, target_text) = outcome_text
        .split_once(OUTCOME_ARROW)
        .unwrap_or((outcome_text, ""));
    let (target, round_limit) =
        match target_text.split_once(ROUND_LIMIT_OPENING) {
            None => (target_text, None),
            Some((target, rounds_text)) => {
                let round_count = rounds_text
                    .strip_suffix(ROUND_LIMIT_CLOSING)
                    .and_then(|count_text| count_text.parse().ok());
                (target, round_count)
            }
        };
    (
        source_name.to_owned(),
        unquote(target),
        Some(condition.to_owned()),
        round_limit,
    )
}

fn split_list_items(list_text: &str) -> Vec<String> {
    let inner = list_text
        .strip_prefix(LIST_OPENING)
        .and_then(|text| text.strip_suffix(LIST_CLOSING))
        .unwrap_or(list_text);
    let mut items = Vec::new();
    let mut item = String::new();
    let mut is_inside_quotes = false;
    for character in inner.chars() {
        if character == QUOTE {
            is_inside_quotes = !is_inside_quotes;
        }
        if character == ITEM_SEPARATOR && !is_inside_quotes {
            items.push(unquote(item.trim_start()));
            item.clear();
        } else {
            item.push(character);
        }
    }
    if !item.is_empty() {
        items.push(unquote(item.trim_start()));
    }
    items
}

fn unquote(text: &str) -> String {
    text.strip_prefix(QUOTE)
        .and_then(|inner| inner.strip_suffix(QUOTE))
        .unwrap_or(text)
        .to_owned()
}
