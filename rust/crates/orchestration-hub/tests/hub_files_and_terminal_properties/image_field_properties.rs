use orchestration_hub::image_dimensions::read_image_dimensions;
use proptest::prelude::*;

use crate::image_bytes::{
    GIF_SIGNATURES, JPEG_BASELINE_FRAME, LARGEST_TWENTY_FOUR_BITS, dimensions,
    extended_webp, gif_header, jpeg_frame, jpeg_image, lossless_webp,
    png_header,
};

const PNG_WIDTH_START: usize = 16;
const GIF_WIDTH_START: usize = 6;
const JPEG_HEIGHT_START: usize = 7;
const LOSSLESS_SIZE_START: usize = 21;
const EXTENDED_WIDTH_START: usize = 24;
const BYTE_BITS: u32 = 8;
const FOURTEEN_BIT_MASK: u32 = 0x3FFF;
const LOSSLESS_HEIGHT_SHIFT: u32 = 14;

fn read_big_endian(bytes: &[u8]) -> u32 {
    let mut value = 0;
    for byte in bytes {
        value = (value << BYTE_BITS) | u32::from(*byte);
    }
    value
}

fn read_little_endian(bytes: &[u8]) -> u32 {
    let mut value = 0;
    for byte in bytes.iter().rev() {
        value = (value << BYTE_BITS) | u32::from(*byte);
    }
    value
}

fn replace_bytes(mut bytes: Vec<u8>, start: usize, field: &[u8]) -> Vec<u8> {
    bytes[start..start + field.len()].copy_from_slice(field);
    bytes
}

fn any_nonzero_field<const LENGTH: usize>()
-> impl Strategy<Value = [u8; LENGTH]> {
    any::<[u8; LENGTH]>().prop_filter("the field is not zero", |field| {
        field.iter().any(|byte| *byte != 0)
    })
}

proptest! {
    #[test]
    fn test_read_big_endian_word_property_matches_a_reference_decoder(
        width_bytes in any_nonzero_field::<4>(),
        height_bytes in any_nonzero_field::<4>(),
    ) {
        let fields = [width_bytes, height_bytes].concat();
        let bytes = replace_bytes(png_header(1, 1), PNG_WIDTH_START, &fields);

        let expected = Some(dimensions(
            read_big_endian(&width_bytes),
            read_big_endian(&height_bytes),
        ));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_big_endian_word_property_highest_byte_comes_first(
        high_byte in 1_u8..=u8::MAX,
    ) {
        let width = u32::from(high_byte) << (3 * BYTE_BITS);

        let bytes = png_header(width, 1);

        prop_assert_eq!(bytes[PNG_WIDTH_START], high_byte);
        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, 1)),
        );
    }

    #[test]
    fn test_read_big_endian_word_property_extreme_sizes_survive(
        width in prop_oneof![Just(1_u32), Just(u32::MAX), Just(1 << 31)],
        height in prop_oneof![Just(1_u32), Just(u32::MAX), Just(1 << 31)],
    ) {
        let bytes = png_header(width, height);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_big_endian_half_property_matches_a_reference_decoder(
        height_bytes in any_nonzero_field::<2>(),
        width_bytes in any_nonzero_field::<2>(),
    ) {
        let frame = jpeg_frame(JPEG_BASELINE_FRAME, 1, 1);
        let fields = [height_bytes, width_bytes].concat();
        let bytes = replace_bytes(
            jpeg_image(&[], &frame),
            JPEG_HEIGHT_START,
            &fields,
        );

        let expected = Some(dimensions(
            read_big_endian(&width_bytes),
            read_big_endian(&height_bytes),
        ));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_big_endian_half_property_swapped_bytes_swap_the_value(
        first_byte in 1_u8..=u8::MAX,
        second_byte in 1_u8..=u8::MAX,
    ) {
        let width = u16::from_be_bytes([first_byte, second_byte]);
        let swapped_width = u16::from_be_bytes([second_byte, first_byte]);

        let bytes =
            jpeg_image(&[], &jpeg_frame(JPEG_BASELINE_FRAME, width, 1));
        let swapped =
            jpeg_image(
                &[],
                &jpeg_frame(JPEG_BASELINE_FRAME, swapped_width, 1),
            );

        let read_width = read_image_dimensions(&bytes).map(|size| size.width);
        let read_swapped =
            read_image_dimensions(&swapped).map(|size| size.width);
        prop_assert_eq!(
            read_width,
            Some(read_big_endian(&[first_byte, second_byte])),
        );
        prop_assert_eq!(
            read_swapped,
            Some(read_big_endian(&[second_byte, first_byte])),
        );
    }

    #[test]
    fn test_read_big_endian_half_property_largest_size_survives(
        width in prop_oneof![Just(1_u16), Just(u16::MAX), Just(256)],
    ) {
        let bytes =
            jpeg_image(&[], &jpeg_frame(JPEG_BASELINE_FRAME, width, width));

        let size = u32::from(width);
        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(size, size)),
        );
    }

    #[test]
    fn test_read_little_endian_half_property_matches_a_reference_decoder(
        width_bytes in any_nonzero_field::<2>(),
        height_bytes in any_nonzero_field::<2>(),
    ) {
        let fields = [width_bytes, height_bytes].concat();
        let header = gif_header(GIF_SIGNATURES[1], 1, 1);
        let bytes = replace_bytes(header, GIF_WIDTH_START, &fields);

        let expected = Some(dimensions(
            read_little_endian(&width_bytes),
            read_little_endian(&height_bytes),
        ));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_little_endian_half_property_lowest_byte_comes_first(
        low_byte in 1_u8..=u8::MAX,
    ) {
        let bytes = gif_header(GIF_SIGNATURES[0], u16::from(low_byte), 1);

        prop_assert_eq!(bytes[GIF_WIDTH_START], low_byte);
        let expected = Some(dimensions(u32::from(low_byte), 1));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_little_endian_half_property_largest_size_survives(
        signature in proptest::sample::select(GIF_SIGNATURES.to_vec()),
    ) {
        let bytes = gif_header(signature, u16::MAX, u16::MAX);

        let largest = u32::from(u16::MAX);
        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(largest, largest)),
        );
    }

    #[test]
    fn test_read_little_endian_word_property_matches_a_reference_decoder(
        packed_bytes in any::<[u8; 4]>(),
    ) {
        let header = lossless_webp(1, 1, 0);
        let bytes = replace_bytes(header, LOSSLESS_SIZE_START, &packed_bytes);

        let packed = read_little_endian(&packed_bytes);
        let width = (packed & FOURTEEN_BIT_MASK) + 1;
        let height =
            ((packed >> LOSSLESS_HEIGHT_SHIFT) & FOURTEEN_BIT_MASK) + 1;
        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, height)),
        );
    }

    #[test]
    fn test_read_little_endian_word_property_width_lives_in_the_low_bits(
        width in 1_u32..=256,
    ) {
        let bytes = lossless_webp(width, 1, 0);

        let low_byte = u8::try_from(width - 1).unwrap_or(u8::MAX);
        prop_assert_eq!(bytes[LOSSLESS_SIZE_START], low_byte);
        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(width, 1)),
        );
    }

    #[test]
    fn test_read_little_endian_word_property_all_ones_give_the_largest(
        top_bits in 0_u32..16,
    ) {
        let largest = 1 << LOSSLESS_HEIGHT_SHIFT;

        let bytes = lossless_webp(largest, largest, top_bits);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(largest, largest)),
        );
    }

    #[test]
    fn test_read_little_endian_triple_property_matches_a_reference_decoder(
        width_bytes in any::<[u8; 3]>(),
        height_bytes in any::<[u8; 3]>(),
    ) {
        let fields = [width_bytes, height_bytes].concat();
        let header = extended_webp(1, 1, 0);
        let bytes = replace_bytes(header, EXTENDED_WIDTH_START, &fields);

        let expected = Some(dimensions(
            read_little_endian(&width_bytes) + 1,
            read_little_endian(&height_bytes) + 1,
        ));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_little_endian_triple_property_never_reads_a_fourth_byte(
        width in 1..=LARGEST_TWENTY_FOUR_BITS,
        height in 1..=LARGEST_TWENTY_FOUR_BITS,
        next_byte in any::<u8>(),
    ) {
        let mut bytes = extended_webp(width, height, 0);
        bytes.push(next_byte);

        let expected = Some(dimensions(width, height));
        prop_assert_eq!(read_image_dimensions(&bytes), expected);
    }

    #[test]
    fn test_read_little_endian_triple_property_largest_size_survives(
        flags in any::<u8>(),
    ) {
        let largest = LARGEST_TWENTY_FOUR_BITS;

        let bytes = extended_webp(largest, largest, flags);

        prop_assert_eq!(
            read_image_dimensions(&bytes),
            Some(dimensions(largest, largest)),
        );
    }
}
