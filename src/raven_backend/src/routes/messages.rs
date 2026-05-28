use std::sync::Arc;

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use chrono::Utc;
use sqlx::Row;
use uuid::Uuid;

use crate::{
    error::{ApiError, ApiResult},
    models::{MessageResponse, MessageStatusResponse, SendMessageRequest},
    services::{
        auth_service::authenticate_token,
        validation::validate_raven_id,
    },
    AppState,
};

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/messages", post(send_message))
        .route("/messages/inbox/:raven_id", get(inbox))
        .route("/messages/outbox/:raven_id/status", get(outbox_status))
        .route("/messages/:id/delivered", post(mark_delivered))
}

fn extract_bearer_token(headers: &HeaderMap) -> ApiResult<String> {
    if let Some(value) = headers.get("x-raven-session") {
        return value
            .to_str()
            .map(|s| s.to_string())
            .map_err(|_| ApiError::Unauthorized("Invalid session header.".to_string()));
    }

    let Some(value) = headers.get(axum::http::header::AUTHORIZATION) else {
        return Err(ApiError::Unauthorized("Missing authorization header.".to_string()));
    };

    let value = value
        .to_str()
        .map_err(|_| ApiError::Unauthorized("Invalid authorization header.".to_string()))?;

    let Some(token) = value.strip_prefix("Bearer ") else {
        return Err(ApiError::Unauthorized("Use Authorization: Bearer <token>.".to_string()));
    };

    Ok(token.to_string())
}

fn message_from_row(row: &sqlx::sqlite::SqliteRow) -> ApiResult<MessageResponse> {
    Ok(MessageResponse {
        id: row.try_get("id")?,
        client_message_id: row.try_get("client_message_id")?,
        sender_raven_id: row.try_get("sender_raven_id")?,
        recipient_raven_id: row.try_get("recipient_raven_id")?,
        encrypted_payload: row.try_get("encrypted_payload")?,
        created_at: row.try_get("created_at")?,
        delivered_at: row.try_get("delivered_at")?,
    })
}

async fn send_message(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<SendMessageRequest>,
) -> ApiResult<Json<MessageResponse>> {
    validate_raven_id(&req.sender_raven_id)?;
    validate_raven_id(&req.recipient_raven_id)?;

    if req.encrypted_payload.trim().is_empty() {
        return Err(ApiError::BadRequest("encrypted_payload is required.".to_string()));
    }

    if req.encrypted_payload.len() > 65_536 {
        return Err(ApiError::BadRequest("encrypted_payload is too large.".to_string()));
    }

    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;

    if user.raven_id != req.sender_raven_id {
        return Err(ApiError::Forbidden("Sender does not match session user.".to_string()));
    }

    let recipient_exists = sqlx::query("SELECT id FROM users WHERE raven_id = ? LIMIT 1")
        .bind(&req.recipient_raven_id)
        .fetch_optional(&state.db)
        .await?
        .is_some();

    if !recipient_exists {
        return Err(ApiError::NotFound("Recipient not found.".to_string()));
    }

    let id = Uuid::new_v4().to_string();
    let created_at = Utc::now().to_rfc3339();

    sqlx::query(
        r#"
        INSERT INTO messages (
            id, client_message_id, sender_raven_id, recipient_raven_id,
            encrypted_payload, created_at, delivered_at, read_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL)
        "#,
    )
    .bind(&id)
    .bind(&req.client_message_id)
    .bind(&req.sender_raven_id)
    .bind(&req.recipient_raven_id)
    .bind(&req.encrypted_payload)
    .bind(&created_at)
    .execute(&state.db)
    .await?;

    Ok(Json(MessageResponse {
        id,
        client_message_id: req.client_message_id,
        sender_raven_id: req.sender_raven_id,
        recipient_raven_id: req.recipient_raven_id,
        encrypted_payload: req.encrypted_payload,
        created_at,
        delivered_at: None,
    }))
}

async fn inbox(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(raven_id): Path<String>,
) -> ApiResult<Json<Vec<MessageResponse>>> {
    validate_raven_id(&raven_id)?;

    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;

    if user.raven_id != raven_id {
        return Err(ApiError::Forbidden("You can only fetch your own inbox.".to_string()));
    }

    let rows = sqlx::query(
        r#"
        SELECT id, client_message_id, sender_raven_id, recipient_raven_id,
               encrypted_payload, created_at, delivered_at
        FROM messages
        WHERE recipient_raven_id = ?
          AND delivered_at IS NULL
        ORDER BY created_at ASC
        LIMIT 100
        "#,
    )
    .bind(&raven_id)
    .fetch_all(&state.db)
    .await?;

    let mut messages = Vec::with_capacity(rows.len());
    for row in rows {
        messages.push(message_from_row(&row)?);
    }

    Ok(Json(messages))
}


async fn outbox_status(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(raven_id): Path<String>,
) -> ApiResult<Json<Vec<MessageStatusResponse>>> {
    validate_raven_id(&raven_id)?;

    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;

    if user.raven_id != raven_id {
        return Err(ApiError::Forbidden("You can only fetch your own outgoing message status.".to_string()));
    }

    let rows = sqlx::query(
        r#"
        SELECT id, client_message_id, recipient_raven_id, delivered_at
        FROM messages
        WHERE sender_raven_id = ?
        ORDER BY created_at DESC
        LIMIT 200
        "#,
    )
    .bind(&raven_id)
    .fetch_all(&state.db)
    .await?;

    let mut statuses = Vec::with_capacity(rows.len());
    for row in rows {
        statuses.push(MessageStatusResponse {
            id: row.try_get("id")?,
            client_message_id: row.try_get("client_message_id")?,
            recipient_raven_id: row.try_get("recipient_raven_id")?,
            delivered_at: row.try_get("delivered_at")?,
        });
    }

    Ok(Json(statuses))
}

async fn mark_delivered(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> ApiResult<Json<MessageResponse>> {
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;

    let row = sqlx::query(
        r#"
        SELECT id, client_message_id, sender_raven_id, recipient_raven_id,
               encrypted_payload, created_at, delivered_at
        FROM messages
        WHERE id = ?
        LIMIT 1
        "#,
    )
    .bind(&id)
    .fetch_optional(&state.db)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::NotFound("Message not found.".to_string()));
    };

    let recipient_raven_id: String = row.try_get("recipient_raven_id")?;
    if recipient_raven_id != user.raven_id {
        return Err(ApiError::Forbidden("Only the recipient can mark this message as delivered.".to_string()));
    }

    let delivered_at = Utc::now().to_rfc3339();
    sqlx::query("UPDATE messages SET delivered_at = ? WHERE id = ?")
        .bind(&delivered_at)
        .bind(&id)
        .execute(&state.db)
        .await?;

    let row = sqlx::query(
        r#"
        SELECT id, client_message_id, sender_raven_id, recipient_raven_id,
               encrypted_payload, created_at, delivered_at
        FROM messages
        WHERE id = ?
        LIMIT 1
        "#,
    )
    .bind(&id)
    .fetch_one(&state.db)
    .await?;

    Ok(Json(message_from_row(&row)?))
}
