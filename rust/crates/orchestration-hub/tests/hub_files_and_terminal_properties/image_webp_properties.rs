use orchestration_hub::image_dimensions::read_image_dimensions;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::image_bytes::{
    LARGEST_FOURTEEN_BITS, LARGEST_TWENTY_FOUR_BITS, dimensions,
    extended_webp, lossless_webp, lossless_webp_with_size, lossy_webp,
    webp_with_chunk,
};

const KNOWN_CHUNKS: [&[u8]; 3] = [b"VP8 ", b"VP8L", b"VP8X"];
const LOSSY_SIZE_LIMIT: u16 = 1 << 14;

fn any_lossless_size() -> impl Strategy<Value = (u32, u32)> {
    (1..=LARGEST_FOURTEEN_BITS, 1..=LARGEST_FOURTEEN_BITS)
}

fn any_extended_size() -> impl Strategy<Value = (u32, u32)> {
    (1..=LARGEST_TWENTY_FOUR_BITS, 1..=LARGEST_TWENTY_FOUR_BITS)
}

proptest! {
    #[test]
    fn test_read_webp_property_needs_both_signatures(
        (width, height) in any_lossless_size(),
        position in 0_usize..12,
        replacement in any::<u8>(),
    ) {
        let mut bytes = lossless_webp(width, height, 0);
        let is_size_byte = (4..8).contains(&position);
        prop_assume!(!is_size_byte && bytes[position] != replacement);
        bytes[position] = replacement;

        prop_assert_eq!(read_image_dimensions(&bytes), None);
    }

    #[test]
    fn test_read_webp_property_unknown_chunks_read_nothing(
        chunk in vec(any::<u8>(), 4),
        tail in vec(any::<u8>(), 0..24),
    ) {
        prop_assume!(!KNOWN_CHUNKS.contains(&chunk.as_slice()));

        let bytes = webp_with_chunk(&chunk, &tail);

        prop_assert_eq!(read_image_dimensions(&bytes), None);
    }

    #[test]
    fn test_read_webp_property_the_file_size_field_never_matters(
        riff_size in any::<[u8; 4]>(),
        (width, height) in any_lossless_size(),
    ) {
        let bytes = lossless_webp_with_size(riff_size, width, height, 0);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_lossy_webp_property_reads_fourteen_bit_sizes(
        width in 1..LOSSY_SIZE_LIMIT,
        height in 1..LOSSY_SIZE_LIMIT,
    ) {
        let bytes = lossy_webp(width, height, (0, 0));

        let expected = Some(dimensions(u32::from(width), u32::from(height)));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_lossy_webp_property_scale_bits_never_change_the_size(
        width in 1..LOSSY_SIZE_LIMIT,
        height in 1..LOSSY_SIZE_LIMIT,
        scales in (0_u16..4, 0_u16..4),
    ) {
        let scaled = lossy_webp(width, height, scales);
        let unscaled = lossy_webp(width, height, (0, 0));

        let expected = read_image_dimensions(&unscaled);
        prop_assert_eq!(read_image_dimensions(&scaled), expected);
    }

    #[test]
    fn test_read_lossy_webp_property_cut_headers_read_nothing(
        width in 1..LOSSY_SIZE_LIMIT,
        height in 1..LOSSY_SIZE_LIMIT,
        cut_length in 1_usize..=4,
    ) {
        let bytes = lossy_webp(width, height, (0, 0));
        let kept_length = bytes.len() - cut_length;

        prop_assert_eq!(read_image_dimensions(&bytes[..kept_length]), None);
    }

    #[test]
    fn test_read_lossless_webp_property_stored_sizes_count_from_one(
        (width, height) in any_lossless_size(),
    ) {
        let bytes = lossless_webp(width, height, 0);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_lossless_webp_property_alpha_and_version_bits_are_ignored(
        (width, height) in any_lossless_size(),
        top_bits in 0_u32..16,
    ) {
        let bytes = lossless_webp(width, height, top_bits);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_lossless_webp_property_cut_headers_read_nothing(
        (width, height) in any_lossless_size(),
        cut_length in 1_usize..=4,
    ) {
        let bytes = lossless_webp(width, height, 0);
        let kept_length = bytes.len() - cut_length;

        prop_assert_eq!(read_image_dimensions(&bytes[..kept_length]), None);
    }

    #[test]
    fn test_read_extended_webp_property_reads_twenty_four_bit_sizes(
        (width, height) in any_extended_size(),
    ) {
        let bytes = extended_webp(width, height, 0);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_extended_webp_property_feature_flags_are_ignored(
        (width, height) in any_extended_size(),
        flags in any::<u8>(),
    ) {
        let bytes = extended_webp(width, height, flags);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_extended_webp_property_cut_headers_read_nothing(
        (width, height) in any_extended_size(),
        cut_length in 1_usize..=3,
    ) {
        let bytes = extended_webp(width, height, 0);
        let kept_length = bytes.len() - cut_length;

        prop_assert_eq!(read_image_dimensions(&bytes[..kept_length]), None);
    }
}
