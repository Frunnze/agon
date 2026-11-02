use argon2::{Algorithm, Argon2, Params, Version};
use zeroize::Zeroizing;

use crate::error::SecurityError;
use crate::pairing::PairingCode;

pub const RENDEZVOUS_SECRET_LENGTH: usize = 32;
const RENDEZVOUS_DOMAIN: &[u8] = b"agents-orchestration/pairing-rendezvous/1";
const MEMORY_KIBIBYTES: u32 = 19_456;
const PASSES: u32 = 2;
const LANES: u32 = 1;

pub type RendezvousSecret = Zeroizing<[u8; RENDEZVOUS_SECRET_LENGTH]>;

pub fn derive_rendezvous_secret(
    code: &PairingCode,
) -> Result<RendezvousSecret, SecurityError> {
    let parameters = Params::new(
        MEMORY_KIBIBYTES,
        PASSES,
        LANES,
        Some(RENDEZVOUS_SECRET_LENGTH),
    )
    .map_err(|_| SecurityError::RendezvousNotDerived)?;
    let derivation =
        Argon2::new(Algorithm::Argon2id, Version::V0x13, parameters);

    let canonical_code = String::from(code.clone());
    let mut secret = Zeroizing::new([0; RENDEZVOUS_SECRET_LENGTH]);
    derivation
        .hash_password_into(
            canonical_code.as_bytes(),
            RENDEZVOUS_DOMAIN,
            secret.as_mut_slice(),
        )
        .map_err(|_| SecurityError::RendezvousNotDerived)?;
    Ok(secret)
}
