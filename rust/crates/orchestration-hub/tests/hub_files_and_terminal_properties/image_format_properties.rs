use orchestration_hub::image_dimensions::read_image_dimensions;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

use crate::image_bytes::{
    GIF_SIGNATURES, JPEG_BASELINE_FRAME, JPEG_FRAME_MARKERS,
    JPEG_MARKER_PREFIX, JPEG_STANDALONE_MARKERS, dimensions, gif_header,
    jpeg_frame, jpeg_image, jpeg_segment, png_header, png_header_with_chunk,
};

const PNG_DIMENSIONS_END: usize = 24;
const GIF_DIMENSIONS_END: usize = 10;
const SKIPPED_SEGMENT_MARKERS: [u8; 6] = [0xE0, 0xE1, 0xDB, 0xC4, 0xC8, 0xCC];

fn any_skipped_segment() -> impl Strategy<Value = Vec<u8>> {
    (
        select(SKIPPED_SEGMENT_MARKERS.to_vec()),
        vec(any::<u8>(), 0..40),
    )
        .prop_map(|(marker, payload)| jpeg_segment(marker, &payload))
}

proptest! {
    #[test]
    fn test_read_png_property_reads_any_size_with_any_tail(
        width in 1..=u32::MAX,
        height in 1..=u32::MAX,
        tail in vec(any::<u8>(), 0..32),
    ) {
        let mut bytes = png_header(width, height);
        bytes.extend(tail);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_png_property_needs_the_header_chunk(
        chunk in vec(any::<u8>(), 4),
        width in 1..=u32::MAX,
        height in 1..=u32::MAX,
    ) {
        prop_assume!(chunk != b"IHDR");

        let bytes = png_header_with_chunk(&chunk, width, height);

        prop_assert_eq!(read_image_dimensions(&bytes), None);
    }

    #[test]
    fn test_read_png_property_cut_headers_read_nothing(
        width in 1..=u32::MAX,
        height in 1..=u32::MAX,
        kept_length in 0..PNG_DIMENSIONS_END,
    ) {
        let bytes = png_header(width, height);

        prop_assert_eq!(read_image_dimensions(&bytes[..kept_length]), None);
    }

    #[test]
    fn test_read_gif_property_reads_both_versions(
        signature in select(GIF_SIGNATURES.to_vec()),
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
        tail in vec(any::<u8>(), 0..32),
    ) {
        let mut bytes = gif_header(signature, width, height);
        bytes.extend(tail);

        let expected = Some(dimensions(u32::from(width), u32::from(height)));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_gif_property_other_versions_read_nothing(
        version in "[0-9]{2}[a-z]",
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
    ) {
        prop_assume!(version != "87a" && version != "89a");
        let signature = format!("GIF{version}");

        let bytes = gif_header(signature.as_bytes(), width, height);

        prop_assert_eq!(read_image_dimensions(&bytes), None);
    }

    #[test]
    fn test_read_gif_property_cut_headers_read_nothing(
        signature in select(GIF_SIGNATURES.to_vec()),
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
        kept_length in 0..GIF_DIMENSIONS_END,
    ) {
        let bytes = gif_header(signature, width, height);

        prop_assert_eq!(read_image_dimensions(&bytes[..kept_length]), None);
    }

    #[test]
    fn test_read_jpeg_property_skips_every_segment_before_the_frame(
        segments in vec(any_skipped_segment(), 0..5),
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
    ) {
        let frame = jpeg_frame(JPEG_BASELINE_FRAME, width, height);

        let bytes = jpeg_image(&segments, &frame);

        let expected = Some(dimensions(u32::from(width), u32::from(height)));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_jpeg_property_fill_and_standalone_markers_are_skipped(
        pieces in vec(
            prop_oneof![
                Just(vec![JPEG_MARKER_PREFIX]),
                select(JPEG_STANDALONE_MARKERS.to_vec())
                    .prop_map(|marker| vec![JPEG_MARKER_PREFIX, marker]),
            ],
            0..6,
        ),
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
    ) {
        let frame = jpeg_frame(JPEG_BASELINE_FRAME, width, height);

        let bytes = jpeg_image(&pieces, &frame);

        let expected = Some(dimensions(u32::from(width), u32::from(height)));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_jpeg_property_broken_markers_read_nothing(
        segments in vec(any_skipped_segment(), 0..3),
        stray_byte in 0_u8..JPEG_MARKER_PREFIX,
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
    ) {
        let mut pieces = segments;
        pieces.push(vec![stray_byte]);
        let frame = jpeg_frame(JPEG_BASELINE_FRAME, width, height);

        let bytes = jpeg_image(&pieces, &frame);

        prop_assert_eq!(read_image_dimensions(&bytes), None);
    }

    #[test]
    fn test_read_jpeg_frame_property_every_frame_kind_gives_the_size(
        marker in select(JPEG_FRAME_MARKERS.to_vec()),
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
    ) {
        let bytes = jpeg_image(&[], &jpeg_frame(marker, width, height));

        let expected = Some(dimensions(u32::from(width), u32::from(height)));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_jpeg_frame_property_only_the_first_frame_counts(
        first in (1..=u16::MAX, 1..=u16::MAX),
        second in (1..=u16::MAX, 1..=u16::MAX),
    ) {
        let first_frame = jpeg_frame(JPEG_BASELINE_FRAME, first.0, first.1);
        let second_frame = jpeg_frame(JPEG_BASELINE_FRAME, second.0, second.1);

        let bytes = jpeg_image(&[first_frame], &second_frame);

        let expected =
            Some(dimensions(u32::from(first.0), u32::from(first.1)));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_jpeg_frame_property_cut_frames_read_nothing(
        marker in select(JPEG_FRAME_MARKERS.to_vec()),
        width in 1..=u16::MAX,
        height in 1..=u16::MAX,
        cut_length in 1_usize..=4,
    ) {
        let bytes = jpeg_image(&[], &jpeg_frame(marker, width, height));
        let kept_length = bytes.len() - cut_length;

        prop_assert_eq!(read_image_dimensions(&bytes[..kept_length]), None);
    }
}
