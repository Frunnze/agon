use axum::body::{Bytes, to_bytes};
use axum::extract::{FromRequest, Request};
use axum::http::{HeaderMap, Uri};
use orchestration_api::routes::{
    DEVICE_HEADER, NONCE_HEADER, SIGNATURE_HEADER, TIMESTAMP_HEADER,
};
use orchestration_core::device::DeviceRole;
use orchestration_core::identifiers::DeviceId;
use orchestration_security::request_signing::{
    RequestHeaderValues, RequestSignature, verify_request,
};

use crate::error::ServerError;
use crate::server::{Server, SharedServer};

const MAXIMUM_BODY_BYTES: usize = 16 * 1024 * 1024;
const NOT_SIGNED: &str = "the request is not signed";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AuthenticatedDevice {
    pub device_id: DeviceId,
    pub role: DeviceRole,
}

impl AuthenticatedDevice {
    pub fn is_client(&self) -> bool {
        matches!(self.role, DeviceRole::Client | DeviceRole::ClientAndRunner)
    }

    pub fn is_runner(&self) -> bool {
        matches!(self.role, DeviceRole::Runner | DeviceRole::ClientAndRunner)
    }

    pub fn require_client(&self) -> Result<(), ServerError> {
        if self.is_client() {
            return Ok(());
        }
        Err(ServerError::Forbidden("only a client device can do this"))
    }

    pub fn require_runner(&self) -> Result<(), ServerError> {
        if self.is_runner() {
            return Ok(());
        }
        Err(ServerError::Forbidden("only a runner device can do this"))
    }
}

#[derive(Debug)]
pub struct SignedRequest {
    pub caller: AuthenticatedDevice,
    pub body: Bytes,
}

impl FromRequest<SharedServer> for SignedRequest {
    type Rejection = ServerError;

    async fn from_request(
        request: Request,
        server: &SharedServer,
    ) -> Result<Self, ServerError> {
        let (parts, body) = request.into_parts();
        let header_values = read_header_values(&parts.headers)?;
        let body = to_bytes(body, MAXIMUM_BODY_BYTES).await.map_err(|_| {
            ServerError::Invalid("the request body is unreadable".to_owned())
        })?;
        let signed_path = read_signed_path(&parts.uri);
        let caller = authenticate(
            server,
            &header_values,
            parts.method.as_str(),
            signed_path,
            &body,
        )?;
        Ok(Self { caller, body })
    }
}

fn authenticate(
    server: &Server,
    header_values: &RequestHeaderValues,
    method: &str,
    path: &str,
    body: &[u8],
) -> Result<AuthenticatedDevice, ServerError> {
    let request_signature =
        RequestSignature::from_header_values(header_values).map_err(|_| {
            ServerError::Unauthenticated("a signing header is malformed")
        })?;
    let device_id = &request_signature.device_id;
    let device = server
        .read(|state| Ok(state.devices.get(device_id).cloned()))?
        .ok_or(ServerError::Unauthenticated("the device is not paired"))?;
    if device.revoked {
        return Err(ServerError::Forbidden("the device has been revoked"));
    }

    let now = server.now();
    verify_request(
        &request_signature,
        &device.signing_public_key,
        method,
        path,
        body,
        now,
    )
    .map_err(|_| {
        ServerError::Unauthenticated("the request signature does not verify")
    })?;
    server.admit_request(&request_signature, now)?;

    Ok(AuthenticatedDevice {
        device_id: device.id,
        role: device.role,
    })
}

fn read_header_values(
    headers: &HeaderMap,
) -> Result<RequestHeaderValues, ServerError> {
    Ok(RequestHeaderValues {
        device_id: read_header(headers, DEVICE_HEADER)?,
        timestamp: read_header(headers, TIMESTAMP_HEADER)?,
        nonce: read_header(headers, NONCE_HEADER)?,
        signature: read_header(headers, SIGNATURE_HEADER)?,
    })
}

fn read_header(
    headers: &HeaderMap,
    header_name: &str,
) -> Result<String, ServerError> {
    let header_value = headers
        .get(header_name)
        .ok_or(ServerError::Unauthenticated(NOT_SIGNED))?;
    let header_text = header_value
        .to_str()
        .map_err(|_| ServerError::Unauthenticated(NOT_SIGNED))?;
    Ok(header_text.to_owned())
}

fn read_signed_path(uri: &Uri) -> &str {
    uri.path_and_query()
        .map_or_else(|| uri.path(), |path_and_query| path_and_query.as_str())
}
