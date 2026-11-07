use axum::Json;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use orchestration_api::updates::ApiErrorBody;
use orchestration_core::local_folders::LocalFolderProblem;
use orchestration_core::naming::NameProblem;
use orchestration_core::protected_files::ProtectedPatternProblem;
use orchestration_core::repository_address::AddressProblem;
use orchestration_core::rule_titles::RuleTitleProblem;
use orchestration_core::run_lifecycle::RunProblem;
use orchestration_core::schedule_rules::ScheduleProblem;
use orchestration_core::workflow_graph::WorkflowProblem;
use thiserror::Error;

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum ServerError {
    #[error("{0}")]
    Unauthenticated(&'static str),
    #[error("{0}")]
    Forbidden(&'static str),
    #[error("{0} was not found")]
    NotFound(&'static str),
    #[error("{0}")]
    Conflict(String),
    #[error("{0}")]
    Invalid(String),
    #[error("the server could not keep its state: {0}")]
    Storage(String),
    #[error("{0}")]
    Internal(&'static str),
    #[error("this app server is a backup")]
    NotActive,
    #[error("the answer names none of the choices: {}", .0.join(", "))]
    UnmatchedAnswer(Vec<String>),
}

impl ServerError {
    fn status(&self) -> StatusCode {
        match self {
            Self::Unauthenticated(_) => StatusCode::UNAUTHORIZED,
            Self::Forbidden(_) => StatusCode::FORBIDDEN,
            Self::NotFound(_) => StatusCode::NOT_FOUND,
            Self::Conflict(_) => StatusCode::CONFLICT,
            Self::Invalid(_) => StatusCode::UNPROCESSABLE_ENTITY,
            Self::NotActive => StatusCode::MISDIRECTED_REQUEST,
            Self::UnmatchedAnswer(_) => StatusCode::BAD_REQUEST,
            Self::Storage(_) | Self::Internal(_) => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
        }
    }
}

impl IntoResponse for ServerError {
    fn into_response(self) -> Response {
        let status = self.status();
        let choices = match &self {
            Self::UnmatchedAnswer(choices) => choices.clone(),
            _ => Vec::new(),
        };
        let error_body = ApiErrorBody {
            message: self.to_string(),
            choices,
        };
        (status, Json(error_body)).into_response()
    }
}

impl From<NameProblem> for ServerError {
    fn from(problem: NameProblem) -> Self {
        Self::Invalid(problem.to_string())
    }
}

impl From<ProtectedPatternProblem> for ServerError {
    fn from(problem: ProtectedPatternProblem) -> Self {
        Self::Invalid(problem.to_string())
    }
}

impl From<RuleTitleProblem> for ServerError {
    fn from(problem: RuleTitleProblem) -> Self {
        Self::Invalid(problem.to_string())
    }
}

impl From<AddressProblem> for ServerError {
    fn from(problem: AddressProblem) -> Self {
        Self::Invalid(problem.to_string())
    }
}

impl From<LocalFolderProblem> for ServerError {
    fn from(problem: LocalFolderProblem) -> Self {
        Self::Invalid(problem.to_string())
    }
}

impl From<WorkflowProblem> for ServerError {
    fn from(problem: WorkflowProblem) -> Self {
        Self::Invalid(problem.to_string())
    }
}

impl From<ScheduleProblem> for ServerError {
    fn from(problem: ScheduleProblem) -> Self {
        Self::Invalid(problem.to_string())
    }
}

impl From<RunProblem> for ServerError {
    fn from(problem: RunProblem) -> Self {
        match problem {
            RunProblem::RunAlreadyFinished => {
                Self::Conflict(problem.to_string())
            }
            _ => Self::Invalid(problem.to_string()),
        }
    }
}
