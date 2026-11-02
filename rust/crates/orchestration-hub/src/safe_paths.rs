use std::path::{Component, Path};

pub(crate) fn is_plain_absolute_path(path: &Path) -> bool {
    if !path.is_absolute() || path.to_str().is_none() {
        return false;
    }

    let mut has_named_component = false;
    for component in path.components() {
        match component {
            Component::Normal(_) => has_named_component = true,
            Component::Prefix(_) | Component::RootDir => {}
            Component::CurDir | Component::ParentDir => return false,
        }
    }
    has_named_component
}
