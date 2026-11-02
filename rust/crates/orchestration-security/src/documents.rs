use orchestration_core::workflow::{SignatureState, WorkflowSignature};

use crate::canonical_message::encode_canonical_message;
use crate::identity::{DeviceIdentity, device_id_for, verify_signature};

const DOCUMENT_DOMAIN: &str = "orchestration-workflow-document-v1";

#[must_use]
pub fn sign_document(
    identity: &DeviceIdentity,
    document: &str,
) -> WorkflowSignature {
    let message = encode_document(document);

    WorkflowSignature {
        signed_by: identity.device_id(),
        signature: identity.sign(&message),
        signed_document: document.to_owned(),
    }
}

#[must_use]
pub fn signature_state(
    signature: Option<&WorkflowSignature>,
    current_document: &str,
    signer_key: Option<&[u8]>,
) -> SignatureState {
    let Some(signature) = signature else {
        return SignatureState::NotSignedYet;
    };
    let Some(signer_key) = signer_key else {
        return SignatureState::ChangedNotSigned;
    };
    if signature.signed_document != current_document {
        return SignatureState::ChangedNotSigned;
    }
    if device_id_for(signer_key) != signature.signed_by {
        return SignatureState::ChangedNotSigned;
    }

    let message = encode_document(current_document);
    match verify_signature(signer_key, &message, &signature.signature) {
        Ok(()) => SignatureState::Signed,
        Err(_) => SignatureState::ChangedNotSigned,
    }
}

fn encode_document(document: &str) -> Vec<u8> {
    encode_canonical_message(DOCUMENT_DOMAIN, &[document.as_bytes()])
}
