use std::time::Duration;

use reqwest::Method;
use serde::Serialize;

use crate::node_error::NodeError;

const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const CONTENT_TYPE_HEADER: &str = "content-type";
const JSON_CONTENT_TYPE: &str = "application/json";

pub(super) type RequestHeader = (&'static str, String);

#[derive(Clone, Debug)]
pub(super) struct OutgoingRequest {
    pub(super) method: Method,
    pub(super) path: String,
    pub(super) headers: Vec<RequestHeader>,
    pub(super) body: Vec<u8>,
    pub(super) timeout: Duration,
}

impl OutgoingRequest {
    pub(super) fn without_body(method: Method, path: &str) -> Self {
        Self {
            method,
            path: path.to_owned(),
            headers: vec![json_content_type()],
            body: Vec::new(),
            timeout: REQUEST_TIMEOUT,
        }
    }

    pub(super) fn with_json_body<Body: Serialize>(
        method: Method,
        path: &str,
        body: &Body,
    ) -> Result<Self, NodeError> {
        Ok(Self {
            method,
            path: path.to_owned(),
            headers: vec![json_content_type()],
            body: serde_json::to_vec(body)?,
            timeout: REQUEST_TIMEOUT,
        })
    }

    pub(super) fn waiting_up_to(self, timeout: Duration) -> Self {
        Self { timeout, ..self }
    }

    pub(super) fn with_headers(self, extra: Vec<RequestHeader>) -> Self {
        let mut headers = self.headers;
        headers.extend(extra);
        Self { headers, ..self }
    }
}

fn json_content_type() -> RequestHeader {
    (CONTENT_TYPE_HEADER, JSON_CONTENT_TYPE.to_owned())
}
