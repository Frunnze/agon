use orchestration_core::device::Device;
use orchestration_core::peer_address::PeerAddress;
use orchestration_security::peer_addresses::verify_peer_address;

use crate::node_error::NodeError;

pub(crate) fn trusted_peer_address(
    device: &Device,
) -> Result<&PeerAddress, NodeError> {
    let untrusted = || NodeError::UntrustedPeerAddress(device.id.0.clone());
    let signed_address = device.peer_address.as_ref().ok_or_else(untrusted)?;
    if signed_address.device_id != device.id {
        return Err(untrusted());
    }
    verify_peer_address(signed_address, &device.signing_public_key)
        .map_err(|_| untrusted())?;
    Ok(&signed_address.address)
}
