use rand_core::{OsRng, RngCore};
use zeroize::Zeroizing;

use crate::error::SecurityError;

pub(crate) fn random_bytes<const LENGTH: usize>()
-> Result<Zeroizing<[u8; LENGTH]>, SecurityError> {
    let mut bytes = Zeroizing::new([0_u8; LENGTH]);
    OsRng
        .try_fill_bytes(bytes.as_mut_slice())
        .map_err(|_| SecurityError::RandomSourceFailed)?;
    Ok(bytes)
}
