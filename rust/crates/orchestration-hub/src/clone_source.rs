use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{
    is_local_address, parse_local_address,
};
use orchestration_core::repository_address::parse_repository_address;
use thiserror::Error;

pub const ADDRESS_PLACEHOLDER: &str = "{address}";
pub const STANDARD_CLONE_TEMPLATE: &str = "https://{address}.git";
const PLACEHOLDERS_PER_TEMPLATE: usize = 1;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CloneSource {
    template: String,
    folder_device: Option<DeviceId>,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum CloneSourceProblem {
    #[error(
        "the clone template {0:?} needs one {placeholder} and no spaces",
        placeholder = ADDRESS_PLACEHOLDER
    )]
    InvalidTemplate(String),
    #[error("{0:?} is not a canonical host/owner/repository address")]
    NonCanonicalAddress(String),
    #[error("{0:?} is a folder on another computer")]
    FolderOnAnotherDevice(String),
}

impl CloneSource {
    #[must_use]
    pub fn standard() -> Self {
        Self {
            template: STANDARD_CLONE_TEMPLATE.to_owned(),
            folder_device: None,
        }
    }

    pub fn from_template(template: &str) -> Result<Self, CloneSourceProblem> {
        let placeholder_count = template.matches(ADDRESS_PLACEHOLDER).count();
        let has_unsafe_character = template.chars().any(|character| {
            character.is_whitespace() || character.is_control()
        });
        if placeholder_count != PLACEHOLDERS_PER_TEMPLATE
            || has_unsafe_character
        {
            return Err(CloneSourceProblem::InvalidTemplate(
                template.to_owned(),
            ));
        }
        Ok(Self {
            template: template.to_owned(),
            folder_device: None,
        })
    }

    #[must_use]
    pub fn on_device(self, device_id: DeviceId) -> Self {
        Self {
            folder_device: Some(device_id),
            ..self
        }
    }

    pub fn clone_url(
        &self,
        address: &str,
    ) -> Result<String, CloneSourceProblem> {
        let canonical_address = parse_repository_address(address);
        if canonical_address.as_deref() != Ok(address) {
            return Err(CloneSourceProblem::NonCanonicalAddress(
                address.to_owned(),
            ));
        }
        if is_local_address(address) {
            return self.folder_path(address);
        }
        Ok(self.template.replacen(ADDRESS_PLACEHOLDER, address, 1))
    }

    fn folder_path(
        &self,
        address: &str,
    ) -> Result<String, CloneSourceProblem> {
        let on_another_device =
            || CloneSourceProblem::FolderOnAnotherDevice(address.to_owned());
        let folder =
            parse_local_address(address).map_err(|_| on_another_device())?;
        if self.folder_device.as_ref() != Some(&folder.device_id) {
            return Err(on_another_device());
        }
        Ok(folder.path)
    }
}
