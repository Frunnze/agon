use serde::de::DeserializeOwned;

use super::draft_kind::DraftKind;
use super::item_draft::ItemDraft;
use crate::node_error::NodeError;

const JSON_OBJECT_START: char = '{';
const JSON_OBJECT_END: char = '}';
const NO_JSON_OBJECT: &str = "the answer holds no JSON object";

pub fn parse_item_answer(
    kind: DraftKind,
    final_message: &str,
) -> Result<ItemDraft, NodeError> {
    let answer_text = cut_json_object(final_message).ok_or_else(|| {
        NodeError::DraftNotItem {
            kind: kind.name(),
            problem: NO_JSON_OBJECT.to_owned(),
        }
    })?;
    let drafted = match kind {
        DraftKind::Task => ItemDraft::Task(read_answer(kind, answer_text)?),
        DraftKind::Job => ItemDraft::Job(read_answer(kind, answer_text)?),
        DraftKind::Project => {
            ItemDraft::Project(read_answer(kind, answer_text)?)
        }
        DraftKind::Skill => ItemDraft::Skill(read_answer(kind, answer_text)?),
        DraftKind::Rule => ItemDraft::Rule(read_answer(kind, answer_text)?),
    };
    Ok(drafted)
}

pub(crate) fn cut_json_object(text: &str) -> Option<&str> {
    let start = text.find(JSON_OBJECT_START)?;
    let end = text.rfind(JSON_OBJECT_END)?;
    text.get(start..=end)
}

fn read_answer<Answer: DeserializeOwned>(
    kind: DraftKind,
    answer_text: &str,
) -> Result<Answer, NodeError> {
    serde_json::from_str(answer_text).map_err(|error| {
        NodeError::DraftNotItem {
            kind: kind.name(),
            problem: error.to_string(),
        }
    })
}
