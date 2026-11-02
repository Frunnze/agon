use orchestration_security::identity::DeviceIdentity;
use reqwest::Method;
use serde::Serialize;
use serde::de::DeserializeOwned;

use super::outgoing_request::OutgoingRequest;
use super::{ServerClient, decode_answer};
use crate::node_error::NodeError;

#[derive(Clone, Copy, Debug)]
pub struct SignedServerClient<'client> {
    server: &'client ServerClient,
    identity: &'client DeviceIdentity,
}

impl<'client> SignedServerClient<'client> {
    pub(super) fn new(
        server: &'client ServerClient,
        identity: &'client DeviceIdentity,
    ) -> Self {
        Self { server, identity }
    }

    pub(super) async fn fetch<Answer: DeserializeOwned>(
        &self,
        path: &str,
    ) -> Result<Answer, NodeError> {
        let request = OutgoingRequest::without_body(Method::GET, path);
        let answer = self.server.send_signed(self.identity, request).await?;
        decode_answer(&answer)
    }

    pub(super) async fn exchange<Body: Serialize, Answer: DeserializeOwned>(
        &self,
        method: Method,
        path: &str,
        body: &Body,
    ) -> Result<Answer, NodeError> {
        let request = OutgoingRequest::with_json_body(method, path, body)?;
        let answer = self.server.send_signed(self.identity, request).await?;
        decode_answer(&answer)
    }

    pub(super) async fn submit<Body: Serialize>(
        &self,
        method: Method,
        path: &str,
        body: &Body,
    ) -> Result<(), NodeError> {
        let request = OutgoingRequest::with_json_body(method, path, body)?;
        self.server.send_signed(self.identity, request).await?;
        Ok(())
    }

    pub(super) async fn submit_without_body(
        &self,
        method: Method,
        path: &str,
    ) -> Result<Vec<u8>, NodeError> {
        let request = OutgoingRequest::without_body(method, path);
        self.server.send_signed(self.identity, request).await
    }

    pub(super) async fn send_request(
        &self,
        request: OutgoingRequest,
    ) -> Result<Vec<u8>, NodeError> {
        self.server.send_signed(self.identity, request).await
    }
}
