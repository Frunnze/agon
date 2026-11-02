use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use orchestration_core::repository_files::FilePreview;

use crate::image_dimensions::read_image_dimensions;

pub const MAXIMUM_TEXT_PREVIEW_BYTES: u64 = 1024 * 1024;
pub const MAXIMUM_IMAGE_PREVIEW_BYTES: u64 = 5 * 1024 * 1024;
const NUL_BYTE: u8 = 0;

#[must_use]
pub fn describe_file_preview(content: &[u8]) -> FilePreview {
    let size = u64::try_from(content.len()).unwrap_or(u64::MAX);
    if size > MAXIMUM_IMAGE_PREVIEW_BYTES {
        return FilePreview::TooLarge;
    }
    if let Some(dimensions) = read_image_dimensions(content) {
        return FilePreview::Image {
            width: dimensions.width,
            height: dimensions.height,
            base64_content: STANDARD.encode(content),
        };
    }
    if size > MAXIMUM_TEXT_PREVIEW_BYTES {
        return FilePreview::TooLarge;
    }
    if content.contains(&NUL_BYTE) {
        return FilePreview::Binary;
    }
    match std::str::from_utf8(content) {
        Ok(text) => FilePreview::Text {
            text: text.to_owned(),
        },
        Err(_) => FilePreview::Binary,
    }
}
