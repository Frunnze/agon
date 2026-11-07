use orchestration_core::repository_files::FilePreview;
use orchestration_hub::file_previews::{
    MAXIMUM_IMAGE_PREVIEW_BYTES, MAXIMUM_TEXT_PREVIEW_BYTES,
    describe_file_preview,
};
use proptest::prelude::*;

use crate::image_bytes::png_header;

const LIMIT_CASES: u32 = 6;
const LONE_CONTINUATION_BYTES: std::ops::Range<u8> = 0x80..0xC0;

fn byte_count(limit: u64, offset: i64) -> usize {
    let count = limit.saturating_add_signed(offset);
    usize::try_from(count).unwrap_or(usize::MAX)
}

fn is_too_large(preview: &FilePreview) -> bool {
    matches!(preview, FilePreview::TooLarge)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LIMIT_CASES))]

    #[test]
    fn test_describe_file_preview_property_text_limit_is_inclusive(
        offset in -2_i64..=2,
        letter in proptest::char::range('a', 'z'),
    ) {
        let length = byte_count(MAXIMUM_TEXT_PREVIEW_BYTES, offset);
        let content = letter.to_string().repeat(length);

        let preview = describe_file_preview(content.as_bytes());

        prop_assert_eq!(is_too_large(&preview), offset > 0);
    }

    #[test]
    fn test_describe_file_preview_property_images_may_pass_the_text_limit(
        offset in -2_i64..=2,
        width in 1_u32..10_000,
    ) {
        let length = byte_count(MAXIMUM_IMAGE_PREVIEW_BYTES, offset);
        let mut content = png_header(width, width);
        content.resize(length, 0);

        let preview = describe_file_preview(&content);

        let is_image = matches!(preview, FilePreview::Image { .. });
        prop_assert_eq!(is_image, offset <= 0);
        prop_assert_eq!(is_too_large(&preview), offset > 0);
    }
}

proptest! {
    #[test]
    fn test_describe_file_preview_property_broken_utf8_is_binary(
        before in "[a-zA-Z0-9 ]{0,40}",
        broken_byte in LONE_CONTINUATION_BYTES,
        after in "[a-zA-Z0-9 ]{0,40}",
    ) {
        let mut content = before.into_bytes();
        content.push(broken_byte);
        content.extend(after.into_bytes());

        prop_assert_eq!(describe_file_preview(&content), FilePreview::Binary);
    }
}
