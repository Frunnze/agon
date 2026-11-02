use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepositoryBranches {
    pub branches: Vec<String>,
    pub task_branches: Vec<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RepositoryEntryKind {
    Folder,
    File,
    Link,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepositoryEntry {
    pub name: String,
    pub kind: RepositoryEntryKind,
    pub size: Option<u64>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum FilePreview {
    Text {
        text: String,
    },
    Image {
        width: u32,
        height: u32,
        base64_content: String,
    },
    TooLarge,
    Binary,
    Link,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepositoryFile {
    pub path: String,
    pub size: u64,
    pub preview: FilePreview,
}

#[must_use]
pub fn order_repository_entries(
    entries: &[RepositoryEntry],
) -> Vec<RepositoryEntry> {
    let mut ordered = entries.to_vec();
    ordered.sort_by(|first, second| {
        let first_key = (!is_folder(first), first.name.to_lowercase());
        let second_key = (!is_folder(second), second.name.to_lowercase());
        first_key
            .cmp(&second_key)
            .then_with(|| first.name.cmp(&second.name))
    });
    ordered
}

fn is_folder(entry: &RepositoryEntry) -> bool {
    entry.kind == RepositoryEntryKind::Folder
}
