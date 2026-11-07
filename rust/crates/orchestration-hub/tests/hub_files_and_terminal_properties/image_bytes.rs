use orchestration_hub::image_dimensions::ImageDimensions;

pub const PNG_SIGNATURE: &[u8] = b"\x89PNG\r\n\x1a\n";
pub const GIF_SIGNATURES: [&[u8]; 2] = [b"GIF87a", b"GIF89a"];
pub const JPEG_FRAME_MARKERS: [u8; 13] = [
    0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE,
    0xCF,
];
pub const JPEG_STANDALONE_MARKERS: [u8; 10] =
    [0x01, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8];
pub const JPEG_MARKER_PREFIX: u8 = 0xFF;
pub const JPEG_BASELINE_FRAME: u8 = 0xC0;
pub const LARGEST_FOURTEEN_BITS: u32 = 1 << 14;
pub const LARGEST_TWENTY_FOUR_BITS: u32 = 1 << 24;

const PNG_HEADER_LENGTH: [u8; 4] = [0, 0, 0, 13];
const PNG_HEADER_CHUNK: &[u8] = b"IHDR";
const PNG_HEADER_REST: [u8; 5] = [8, 6, 0, 0, 0];
const JPEG_START: [u8; 2] = [0xFF, 0xD8];
const JPEG_FRAME_START: [u8; 3] = [0x00, 0x11, 0x08];
const JPEG_LENGTH_BYTES: usize = 2;
const RIFF_SIGNATURE: &[u8] = b"RIFF";
const WEBP_SIGNATURE: &[u8] = b"WEBP";
const LOSSY_CHUNK: &[u8] = b"VP8 ";
const LOSSLESS_CHUNK: &[u8] = b"VP8L";
const EXTENDED_CHUNK: &[u8] = b"VP8X";
const LOSSY_FRAME_TAG: [u8; 6] = [0x10, 0x02, 0x00, 0x9D, 0x01, 0x2A];
const LOSSLESS_SIGNATURE: u8 = 0x2F;
const LOSSLESS_HEIGHT_SHIFT: u32 = 14;
const LOSSY_SCALE_SHIFT: u16 = 14;
const TRIPLE_LENGTH: usize = 3;

pub fn dimensions(width: u32, height: u32) -> ImageDimensions {
    ImageDimensions { width, height }
}

pub fn png_header(width: u32, height: u32) -> Vec<u8> {
    png_header_with_chunk(PNG_HEADER_CHUNK, width, height)
}

pub fn png_header_with_chunk(
    chunk: &[u8],
    width: u32,
    height: u32,
) -> Vec<u8> {
    let mut bytes = PNG_SIGNATURE.to_vec();
    bytes.extend_from_slice(&PNG_HEADER_LENGTH);
    bytes.extend_from_slice(chunk);
    bytes.extend_from_slice(&width.to_be_bytes());
    bytes.extend_from_slice(&height.to_be_bytes());
    bytes.extend_from_slice(&PNG_HEADER_REST);
    bytes
}

pub fn gif_header(signature: &[u8], width: u16, height: u16) -> Vec<u8> {
    let mut bytes = signature.to_vec();
    bytes.extend_from_slice(&width.to_le_bytes());
    bytes.extend_from_slice(&height.to_le_bytes());
    bytes
}

pub fn jpeg_segment(marker: u8, payload: &[u8]) -> Vec<u8> {
    let length = payload.len() + JPEG_LENGTH_BYTES;
    let length = u16::try_from(length).unwrap_or(u16::MAX);
    let mut bytes = vec![JPEG_MARKER_PREFIX, marker];
    bytes.extend_from_slice(&length.to_be_bytes());
    bytes.extend_from_slice(payload);
    bytes
}

pub fn jpeg_frame(marker: u8, width: u16, height: u16) -> Vec<u8> {
    let mut bytes = vec![JPEG_MARKER_PREFIX, marker];
    bytes.extend_from_slice(&JPEG_FRAME_START);
    bytes.extend_from_slice(&height.to_be_bytes());
    bytes.extend_from_slice(&width.to_be_bytes());
    bytes
}

pub fn jpeg_image(before_frame: &[Vec<u8>], frame: &[u8]) -> Vec<u8> {
    let mut bytes = JPEG_START.to_vec();
    for piece in before_frame {
        bytes.extend_from_slice(piece);
    }
    bytes.extend_from_slice(frame);
    bytes
}

fn webp_start(riff_size: [u8; 4], chunk: &[u8]) -> Vec<u8> {
    let mut bytes = RIFF_SIGNATURE.to_vec();
    bytes.extend_from_slice(&riff_size);
    bytes.extend_from_slice(WEBP_SIGNATURE);
    bytes.extend_from_slice(chunk);
    bytes.extend_from_slice(&[0; 4]);
    bytes
}

pub fn lossy_webp(width: u16, height: u16, scales: (u16, u16)) -> Vec<u8> {
    let mut bytes = webp_start([0; 4], LOSSY_CHUNK);
    bytes.extend_from_slice(&LOSSY_FRAME_TAG);
    let stored_width = width | (scales.0 << LOSSY_SCALE_SHIFT);
    let stored_height = height | (scales.1 << LOSSY_SCALE_SHIFT);
    bytes.extend_from_slice(&stored_width.to_le_bytes());
    bytes.extend_from_slice(&stored_height.to_le_bytes());
    bytes
}

pub fn lossless_webp(width: u32, height: u32, top_bits: u32) -> Vec<u8> {
    lossless_webp_with_size([0; 4], width, height, top_bits)
}

pub fn lossless_webp_with_size(
    riff_size: [u8; 4],
    width: u32,
    height: u32,
    top_bits: u32,
) -> Vec<u8> {
    let mut bytes = webp_start(riff_size, LOSSLESS_CHUNK);
    bytes.push(LOSSLESS_SIGNATURE);
    let stored_size = (width - 1) | ((height - 1) << LOSSLESS_HEIGHT_SHIFT);
    let packed = stored_size | (top_bits << (2 * LOSSLESS_HEIGHT_SHIFT));
    bytes.extend_from_slice(&packed.to_le_bytes());
    bytes
}

pub fn extended_webp(width: u32, height: u32, flags: u8) -> Vec<u8> {
    let mut bytes = webp_start([0; 4], EXTENDED_CHUNK);
    bytes.extend_from_slice(&[flags, 0, 0, 0]);
    bytes.extend_from_slice(&(width - 1).to_le_bytes()[..TRIPLE_LENGTH]);
    bytes.extend_from_slice(&(height - 1).to_le_bytes()[..TRIPLE_LENGTH]);
    bytes
}

pub fn webp_with_chunk(chunk: &[u8], tail: &[u8]) -> Vec<u8> {
    let mut bytes = webp_start([0; 4], chunk);
    bytes.extend_from_slice(tail);
    bytes
}
