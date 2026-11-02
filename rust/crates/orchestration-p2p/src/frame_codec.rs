use thiserror::Error;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

pub const MAXIMUM_FRAME_SIZE: usize = 16 * 1024 * 1024;
pub const FRAME_LENGTH_PREFIX_SIZE: usize = 4;

pub type FrameLengthPrefix = [u8; FRAME_LENGTH_PREFIX_SIZE];

#[derive(Debug, Error)]
pub enum FrameError {
    #[error(
        "frame payload of {payload_length} bytes exceeds the maximum of \
         {MAXIMUM_FRAME_SIZE} bytes"
    )]
    FrameTooLarge { payload_length: usize },
    #[error("frame stream failed: {0}")]
    Stream(#[from] std::io::Error),
}

pub fn encode_frame_length(
    payload_length: usize,
) -> Result<FrameLengthPrefix, FrameError> {
    match u32::try_from(payload_length) {
        Ok(payload_word) if payload_length <= MAXIMUM_FRAME_SIZE => {
            Ok(payload_word.to_be_bytes())
        }
        _ => Err(FrameError::FrameTooLarge { payload_length }),
    }
}

pub fn decode_frame_length(
    length_prefix: FrameLengthPrefix,
) -> Result<usize, FrameError> {
    let payload_word = u32::from_be_bytes(length_prefix);
    let payload_length = payload_word as usize;
    if payload_length > MAXIMUM_FRAME_SIZE {
        return Err(FrameError::FrameTooLarge { payload_length });
    }
    Ok(payload_length)
}

pub async fn write_frame<Writer>(
    writer: &mut Writer,
    payload: &[u8],
) -> Result<(), FrameError>
where
    Writer: AsyncWrite + Unpin,
{
    let length_prefix = encode_frame_length(payload.len())?;
    writer.write_all(&length_prefix).await?;
    writer.write_all(payload).await?;
    Ok(())
}

pub async fn read_frame<Reader>(
    reader: &mut Reader,
) -> Result<Option<Vec<u8>>, FrameError>
where
    Reader: AsyncRead + Unpin,
{
    let mut length_prefix: FrameLengthPrefix = [0; FRAME_LENGTH_PREFIX_SIZE];
    let first_read_length = reader.read(&mut length_prefix).await?;
    if first_read_length == 0 {
        return Ok(None);
    }

    reader
        .read_exact(&mut length_prefix[first_read_length..])
        .await?;
    let payload_length = decode_frame_length(length_prefix)?;

    let mut payload = vec![0; payload_length];
    reader.read_exact(&mut payload).await?;
    Ok(Some(payload))
}
