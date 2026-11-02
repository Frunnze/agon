use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use orchestration_core::repository_files::FilePreview;
use orchestration_hub::file_previews::{
    MAXIMUM_IMAGE_PREVIEW_BYTES, MAXIMUM_TEXT_PREVIEW_BYTES,
    describe_file_preview,
};
use orchestration_hub::image_dimensions::{
    ImageDimensions, read_image_dimensions,
};
use proptest::collection::vec;
use proptest::prelude::*;

const PNG_SIGNATURE: &[u8] = b"\x89PNG\r\n\x1a\n";
const PNG_HEADER_LENGTH: [u8; 4] = [0, 0, 0, 13];

fn build_png_header(width: u32, height: u32) -> Vec<u8> {
    let mut bytes = PNG_SIGNATURE.to_vec();
    bytes.extend_from_slice(&PNG_HEADER_LENGTH);
    bytes.extend_from_slice(b"IHDR");
    bytes.extend_from_slice(&width.to_be_bytes());
    bytes.extend_from_slice(&height.to_be_bytes());
    bytes.extend_from_slice(&[8, 6, 0, 0, 0]);
    bytes
}

fn build_gif_header(width: u16, height: u16) -> Vec<u8> {
    let mut bytes = b"GIF89a".to_vec();
    bytes.extend_from_slice(&width.to_le_bytes());
    bytes.extend_from_slice(&height.to_le_bytes());
    bytes
}

fn build_jpeg_header(width: u16, height: u16, padding: usize) -> Vec<u8> {
    let mut bytes = vec![0xFF, 0xD8, 0xFF, 0xE0];
    let segment_length = u16::try_from(padding + 2).unwrap_or(u16::MAX);
    bytes.extend_from_slice(&segment_length.to_be_bytes());
    bytes.extend(std::iter::repeat_n(0, padding));
    bytes.extend_from_slice(&[0xFF, 0xC0, 0x00, 0x11, 0x08]);
    bytes.extend_from_slice(&height.to_be_bytes());
    bytes.extend_from_slice(&width.to_be_bytes());
    bytes
}

fn build_lossless_webp_header(width: u32, height: u32) -> Vec<u8> {
    let mut bytes = b"RIFF".to_vec();
    bytes.extend_from_slice(&[0; 4]);
    bytes.extend_from_slice(b"WEBPVP8L");
    bytes.extend_from_slice(&[0; 4]);
    bytes.push(0x2F);
    let packed = (width - 1) | ((height - 1) << 14);
    bytes.extend_from_slice(&packed.to_le_bytes());
    bytes
}

fn printable_text() -> impl Strategy<Value = String> {
    "[A-Za-z0-9 \\n\\t{}();=\"'.,é漢]{0,200}"
}

proptest! {
    #[test]
    fn test_read_image_dimensions_property_reads_png_headers(
        width in 1..u32::MAX,
        height in 1..u32::MAX,
    ) {
        let header = build_png_header(width, height);

        prop_assert_eq!(
            read_image_dimensions(&header),
            Some(ImageDimensions { width, height })
        );
    }

    #[test]
    fn test_read_image_dimensions_property_reads_gif_headers(
        width in 1..u16::MAX,
        height in 1..u16::MAX,
    ) {
        let header = build_gif_header(width, height);

        let expected = ImageDimensions {
            width: u32::from(width),
            height: u32::from(height),
        };
        prop_assert_eq!(read_image_dimensions(&header), Some(expected));
    }

    #[test]
    fn test_read_image_dimensions_property_skips_jpeg_segments(
        width in 1..u16::MAX,
        height in 1..u16::MAX,
        padding in 0_usize..300,
    ) {
        let header = build_jpeg_header(width, height, padding);

        let expected = ImageDimensions {
            width: u32::from(width),
            height: u32::from(height),
        };
        prop_assert_eq!(read_image_dimensions(&header), Some(expected));
    }

    #[test]
    fn test_read_image_dimensions_property_reads_lossless_webp(
        width in 1_u32..=16384,
        height in 1_u32..=16384,
    ) {
        let header = build_lossless_webp_header(width, height);

        prop_assert_eq!(
            read_image_dimensions(&header),
            Some(ImageDimensions { width, height })
        );
    }

    #[test]
    fn test_read_image_dimensions_fuzz_never_reports_an_empty_image(
        bytes in vec(any::<u8>(), 0..64),
    ) {
        if let Some(dimensions) = read_image_dimensions(&bytes) {
            prop_assert!(dimensions.width > 0 && dimensions.height > 0);
        }
    }

    #[test]
    fn test_describe_file_preview_property_shows_short_text(
        text in printable_text(),
    ) {
        prop_assert_eq!(
            describe_file_preview(text.as_bytes()),
            FilePreview::Text { text: text.clone() }
        );
    }

    #[test]
    fn test_describe_file_preview_property_refuses_bytes_with_nul(
        before in printable_text(),
        after in printable_text(),
    ) {
        let content = format!("{before}\0{after}");

        prop_assert_eq!(
            describe_file_preview(content.as_bytes()),
            FilePreview::Binary
        );
    }

    #[test]
    fn test_describe_file_preview_property_sends_images_as_base64(
        width in 1..u32::MAX,
        height in 1..u32::MAX,
        tail in vec(any::<u8>(), 0..64),
    ) {
        let mut content = build_png_header(width, height);
        content.extend(tail);

        let preview = describe_file_preview(&content);

        let FilePreview::Image {
            width: shown_width,
            height: shown_height,
            base64_content,
        } = preview
        else {
            return Err(TestCaseError::fail("the image is not shown"));
        };
        prop_assert_eq!((shown_width, shown_height), (width, height));
        prop_assert_eq!(STANDARD.decode(base64_content).ok(), Some(content));
    }

    #[test]
    fn test_describe_file_preview_fuzz_text_previews_are_exact(
        content in vec(any::<u8>(), 0..256),
    ) {
        match describe_file_preview(&content) {
            FilePreview::Text { text } => {
                prop_assert_eq!(text.as_bytes(), content.as_slice());
                prop_assert!(!content.contains(&0));
            }
            FilePreview::Image { .. } | FilePreview::Binary => {}
            FilePreview::TooLarge | FilePreview::Link => {
                return Err(TestCaseError::fail("a short file is previewed"));
            }
        }
    }
}

#[test]
fn test_describe_file_preview_refuses_text_over_the_text_limit() {
    let length = usize::try_from(MAXIMUM_TEXT_PREVIEW_BYTES).unwrap_or(0);
    let content = vec![b'a'; length + 1];

    assert_eq!(describe_file_preview(&content), FilePreview::TooLarge);
    assert!(matches!(
        describe_file_preview(&content[..length]),
        FilePreview::Text { .. }
    ));
}

#[test]
fn test_describe_file_preview_refuses_images_over_the_image_limit() {
    let length = usize::try_from(MAXIMUM_IMAGE_PREVIEW_BYTES).unwrap_or(0);
    let mut content = build_png_header(2, 3);
    content.resize(length + 1, 0);

    assert_eq!(describe_file_preview(&content), FilePreview::TooLarge);
    content.truncate(length);
    assert!(matches!(
        describe_file_preview(&content),
        FilePreview::Image { .. }
    ));
}

#[test]
fn test_describe_file_preview_refuses_text_that_is_not_utf8() {
    let content = [b'a', 0xC3, 0x28, b'b'];

    assert_eq!(describe_file_preview(&content), FilePreview::Binary);
}
