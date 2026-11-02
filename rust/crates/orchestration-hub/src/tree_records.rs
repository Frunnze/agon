use orchestration_core::repository_files::{
    RepositoryEntry, RepositoryEntryKind,
};

use crate::repository_reading::RepositoryReadError;

const NAME_SEPARATOR: char = '\t';
const TREE_TYPE: &str = "tree";
const BLOB_TYPE: &str = "blob";
const LINK_MODE: &str = "120000";

#[derive(Debug)]
pub(crate) struct TreeRecord {
    pub(crate) entry: RepositoryEntry,
    pub(crate) object: String,
}

pub(crate) fn parse_tree_record(
    line: &str,
) -> Result<Option<TreeRecord>, RepositoryReadError> {
    let unreadable = || RepositoryReadError::UnreadableAnswer(line.into());
    let (description, name) =
        line.split_once(NAME_SEPARATOR).ok_or_else(unreadable)?;
    let fields: Vec<&str> = description.split_whitespace().collect();
    let [mode, object_type, object, size] = fields[..] else {
        return Err(unreadable());
    };

    let kind = match (object_type, mode) {
        (TREE_TYPE, _) => RepositoryEntryKind::Folder,
        (BLOB_TYPE, LINK_MODE) => RepositoryEntryKind::Link,
        (BLOB_TYPE, _) => RepositoryEntryKind::File,
        _ => return Ok(None),
    };
    let size = match kind {
        RepositoryEntryKind::Folder => None,
        RepositoryEntryKind::File | RepositoryEntryKind::Link => {
            Some(size.parse::<u64>().map_err(|_| unreadable())?)
        }
    };
    let entry = RepositoryEntry {
        name: name.to_owned(),
        kind,
        size,
    };
    Ok(Some(TreeRecord {
        entry,
        object: object.to_owned(),
    }))
}
