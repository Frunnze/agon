use orchestration_api::accounts::DeviceRegistration;
use orchestration_core::device::{DeviceRole, HardwareKeyKind};
use orchestration_security::identity::DeviceIdentity;

const THIS_DEVICE_KEY_KIND: HardwareKeyKind = HardwareKeyKind::Software;

pub(super) fn register_this_device(
    identity: &DeviceIdentity,
    name: String,
    role: DeviceRole,
) -> DeviceRegistration {
    let public_identity = identity.public_identity();
    DeviceRegistration {
        name,
        role,
        key_kind: THIS_DEVICE_KEY_KIND,
        signing_public_key: public_identity.signing_public_key,
        sealing_public_key: public_identity.sealing_public_key,
    }
}
