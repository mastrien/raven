use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("{0}")]
    BadRequest(String),

    #[error("{0}")]
    Unauthorized(String),

    #[error("{0}")]
    Forbidden(String),

    #[error("{0}")]
    NotFound(String),

    #[error("{0}")]
    Conflict(String),

    #[error("Database error")]
    Sqlx(#[from] sqlx::Error),

    #[error("Internal error: {0}")]
    Internal(String),
}

pub type ApiResult<T> = Result<T, ApiError>;

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, code, message) = match &self {
            ApiError::BadRequest(message) => (StatusCode::BAD_REQUEST, "bad_request", message.clone()),
            ApiError::Unauthorized(message) => (StatusCode::UNAUTHORIZED, "unauthorized", message.clone()),
            ApiError::Forbidden(message) => (StatusCode::FORBIDDEN, "forbidden", message.clone()),
            ApiError::NotFound(message) => (StatusCode::NOT_FOUND, "not_found", message.clone()),
            ApiError::Conflict(message) => (StatusCode::CONFLICT, "conflict", message.clone()),
            ApiError::Sqlx(_) => (StatusCode::INTERNAL_SERVER_ERROR, "database_error", "Database error".to_string()),
            ApiError::Internal(message) => (StatusCode::INTERNAL_SERVER_ERROR, "internal_error", message.clone()),
        };

        let body = Json(json!({
            "error": {
                "code": code,
                "message": message,
            }
        }));

        (status, body).into_response()
    }
}
