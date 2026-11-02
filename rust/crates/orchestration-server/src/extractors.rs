use axum::extract::{FromRequestParts, Path, Query};
use axum::http::request::Parts;
use serde::de::DeserializeOwned;

use crate::error::ServerError;

#[derive(Debug)]
pub struct PathValue<Value>(pub Value);

#[derive(Debug)]
pub struct QueryValue<Value>(pub Value);

impl<State, Value> FromRequestParts<State> for PathValue<Value>
where
    State: Send + Sync,
    Value: DeserializeOwned + Send,
{
    type Rejection = ServerError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &State,
    ) -> Result<Self, ServerError> {
        let Path(value) = Path::<Value>::from_request_parts(parts, state)
            .await
            .map_err(|_| ServerError::NotFound("the addressed item"))?;
        Ok(Self(value))
    }
}

impl<State, Value> FromRequestParts<State> for QueryValue<Value>
where
    State: Send + Sync,
    Value: DeserializeOwned + Send,
{
    type Rejection = ServerError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &State,
    ) -> Result<Self, ServerError> {
        let Query(value) = Query::<Value>::from_request_parts(parts, state)
            .await
            .map_err(|problem| ServerError::Invalid(problem.body_text()))?;
        Ok(Self(value))
    }
}

pub fn parse_json_body<Body: DeserializeOwned>(
    body: &[u8],
) -> Result<Body, ServerError> {
    serde_json::from_slice(body).map_err(|problem| {
        ServerError::Invalid(format!("the request body is invalid: {problem}"))
    })
}
