const PNG_SIGNATURE: &[u8] = b"\x89PNG\r\n\x1a\n";
const PNG_HEADER_CHUNK: &[u8] = b"IHDR";
const PNG_HEADER_CHUNK_START: usize = 12;
const PNG_WIDTH_START: usize = 16;
const PNG_HEIGHT_START: usize = 20;
const GIF_SIGNATURES: [&[u8]; 2] = [b"GIF87a", b"GIF89a"];
const GIF_WIDTH_START: usize = 6;
const GIF_HEIGHT_START: usize = 8;
const JPEG_SIGNATURE: &[u8] = &[0xFF, 0xD8];
const JPEG_MARKER_PREFIX: u8 = 0xFF;
const JPEG_FRAME_MARKERS: [u8; 13] = [
    0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE,
    0xCF,
];
const JPEG_STANDALONE_MARKERS: [u8; 10] =
    [0x01, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8];
const JPEG_MARKER_LENGTH: usize = 2;
const JPEG_HEIGHT_OFFSET: usize = 5;
const JPEG_WIDTH_OFFSET: usize = 7;
const RIFF_SIGNATURE: &[u8] = b"RIFF";
const WEBP_SIGNATURE: &[u8] = b"WEBP";
const WEBP_SIGNATURE_START: usize = 8;
const WEBP_CHUNK_START: usize = 12;
const WEBP_LOSSY_CHUNK: &[u8] = b"VP8 ";
const WEBP_LOSSLESS_CHUNK: &[u8] = b"VP8L";
const WEBP_EXTENDED_CHUNK: &[u8] = b"VP8X";
const WEBP_LOSSY_WIDTH_START: usize = 26;
const WEBP_LOSSY_HEIGHT_START: usize = 28;
const WEBP_LOSSY_SIZE_MASK: u16 = 0x3FFF;
const WEBP_LOSSLESS_SIZE_START: usize = 21;
const WEBP_LOSSLESS_SIZE_MASK: u32 = 0x3FFF;
const WEBP_LOSSLESS_HEIGHT_SHIFT: u32 = 14;
const WEBP_EXTENDED_WIDTH_START: usize = 24;
const WEBP_EXTENDED_HEIGHT_START: usize = 27;
const WEBP_STORED_SIZE_OFFSET: u32 = 1;
const TRIPLE_LENGTH: usize = 3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ImageDimensions {
    pub width: u32,
    pub height: u32,
}

#[must_use]
pub fn read_image_dimensions(bytes: &[u8]) -> Option<ImageDimensions> {
    let dimensions = read_png(bytes)
        .or_else(|| read_gif(bytes))
        .or_else(|| read_jpeg(bytes))
        .or_else(|| read_webp(bytes))?;
    let is_visible = dimensions.width > 0 && dimensions.height > 0;
    is_visible.then_some(dimensions)
}

fn read_png(bytes: &[u8]) -> Option<ImageDimensions> {
    let header_end = PNG_HEADER_CHUNK_START + PNG_HEADER_CHUNK.len();
    let is_png = bytes.starts_with(PNG_SIGNATURE)
        && bytes.get(PNG_HEADER_CHUNK_START..header_end)
            == Some(PNG_HEADER_CHUNK);
    if !is_png {
        return None;
    }
    Some(ImageDimensions {
        width: read_big_endian_word(bytes, PNG_WIDTH_START)?,
        height: read_big_endian_word(bytes, PNG_HEIGHT_START)?,
    })
}

fn read_gif(bytes: &[u8]) -> Option<ImageDimensions> {
    if !GIF_SIGNATURES
        .iter()
        .any(|signature| bytes.starts_with(signature))
    {
        return None;
    }
    Some(ImageDimensions {
        width: u32::from(read_little_endian_half(bytes, GIF_WIDTH_START)?),
        height: u32::from(read_little_endian_half(bytes, GIF_HEIGHT_START)?),
    })
}

fn read_jpeg(bytes: &[u8]) -> Option<ImageDimensions> {
    if !bytes.starts_with(JPEG_SIGNATURE) {
        return None;
    }
    let mut position = JPEG_SIGNATURE.len();
    loop {
        if *bytes.get(position)? != JPEG_MARKER_PREFIX {
            return None;
        }
        let marker = *bytes.get(position + 1)?;
        if marker == JPEG_MARKER_PREFIX {
            position += 1;
            continue;
        }
        if JPEG_STANDALONE_MARKERS.contains(&marker) {
            position += JPEG_MARKER_LENGTH;
            continue;
        }
        if JPEG_FRAME_MARKERS.contains(&marker) {
            return read_jpeg_frame(bytes, position);
        }
        let length_start = position + JPEG_MARKER_LENGTH;
        let segment_length = read_big_endian_half(bytes, length_start)?;
        position = length_start + usize::from(segment_length);
    }
}

fn read_jpeg_frame(bytes: &[u8], position: usize) -> Option<ImageDimensions> {
    let height = read_big_endian_half(bytes, position + JPEG_HEIGHT_OFFSET)?;
    let width = read_big_endian_half(bytes, position + JPEG_WIDTH_OFFSET)?;
    Some(ImageDimensions {
        width: u32::from(width),
        height: u32::from(height),
    })
}

fn read_webp(bytes: &[u8]) -> Option<ImageDimensions> {
    let signature_end = WEBP_SIGNATURE_START + WEBP_SIGNATURE.len();
    let is_webp = bytes.starts_with(RIFF_SIGNATURE)
        && bytes.get(WEBP_SIGNATURE_START..signature_end)
            == Some(WEBP_SIGNATURE);
    if !is_webp {
        return None;
    }
    let chunk_end = WEBP_CHUNK_START + WEBP_LOSSY_CHUNK.len();
    let chunk = bytes.get(WEBP_CHUNK_START..chunk_end)?;
    if chunk == WEBP_LOSSY_CHUNK {
        return read_lossy_webp(bytes);
    }
    if chunk == WEBP_LOSSLESS_CHUNK {
        return read_lossless_webp(bytes);
    }
    if chunk == WEBP_EXTENDED_CHUNK {
        return read_extended_webp(bytes);
    }
    None
}

fn read_lossy_webp(bytes: &[u8]) -> Option<ImageDimensions> {
    let width = read_little_endian_half(bytes, WEBP_LOSSY_WIDTH_START)?;
    let height = read_little_endian_half(bytes, WEBP_LOSSY_HEIGHT_START)?;
    Some(ImageDimensions {
        width: u32::from(width & WEBP_LOSSY_SIZE_MASK),
        height: u32::from(height & WEBP_LOSSY_SIZE_MASK),
    })
}

fn read_lossless_webp(bytes: &[u8]) -> Option<ImageDimensions> {
    let packed = read_little_endian_word(bytes, WEBP_LOSSLESS_SIZE_START)?;
    let stored_width = packed & WEBP_LOSSLESS_SIZE_MASK;
    let stored_height =
        (packed >> WEBP_LOSSLESS_HEIGHT_SHIFT) & WEBP_LOSSLESS_SIZE_MASK;
    Some(ImageDimensions {
        width: stored_width + WEBP_STORED_SIZE_OFFSET,
        height: stored_height + WEBP_STORED_SIZE_OFFSET,
    })
}

fn read_extended_webp(bytes: &[u8]) -> Option<ImageDimensions> {
    let width = read_little_endian_triple(bytes, WEBP_EXTENDED_WIDTH_START)?;
    let height = read_little_endian_triple(bytes, WEBP_EXTENDED_HEIGHT_START)?;
    Some(ImageDimensions {
        width: width + WEBP_STORED_SIZE_OFFSET,
        height: height + WEBP_STORED_SIZE_OFFSET,
    })
}

fn read_big_endian_word(bytes: &[u8], start: usize) -> Option<u32> {
    let end = start + size_of::<u32>();
    let word: [u8; 4] = bytes.get(start..end)?.try_into().ok()?;
    Some(u32::from_be_bytes(word))
}

fn read_big_endian_half(bytes: &[u8], start: usize) -> Option<u16> {
    let end = start + size_of::<u16>();
    let half: [u8; 2] = bytes.get(start..end)?.try_into().ok()?;
    Some(u16::from_be_bytes(half))
}

fn read_little_endian_half(bytes: &[u8], start: usize) -> Option<u16> {
    let end = start + size_of::<u16>();
    let half: [u8; 2] = bytes.get(start..end)?.try_into().ok()?;
    Some(u16::from_le_bytes(half))
}

fn read_little_endian_word(bytes: &[u8], start: usize) -> Option<u32> {
    let end = start + size_of::<u32>();
    let word: [u8; 4] = bytes.get(start..end)?.try_into().ok()?;
    Some(u32::from_le_bytes(word))
}

fn read_little_endian_triple(bytes: &[u8], start: usize) -> Option<u32> {
    let triple = bytes.get(start..start + TRIPLE_LENGTH)?;
    let mut word = [0; 4];
    word[..TRIPLE_LENGTH].copy_from_slice(triple);
    Some(u32::from_le_bytes(word))
}
