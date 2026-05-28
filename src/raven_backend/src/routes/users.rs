use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, patch},
    Json, Router,
};
use chrono::Utc;

use crate::{
    error::{ApiError, ApiResult},
    models::{SearchQuery, UpdateProfileRequest, UserPublic},
    services::{
        auth_service::{authenticate_token, public_user_from_row},
        validation::{validate_display_name, validate_raven_id},
    },
    AppState,
};

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/search", get(search_users))
        .route("/me/profile", patch(update_my_profile))
        .route("/:raven_id", get(get_user))
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

async fn search_users(
    State(state): State<Arc<AppState>>,
    Query(query): Query<SearchQuery>,
) -> ApiResult<Json<Vec<UserPublic>>> {
    let q = query.q.unwrap_or_default().trim().to_string();

    if q.is_empty() {
        return Ok(Json(Vec::new()));
    }

    if q.len() > 64 {
        return Err(ApiError::BadRequest("Search query is too long.".to_string()));
    }

    let like = format!("%{}%", q.to_lowercase());
    let rows = sqlx::query(
        r#"
        SELECT raven_id, display_name, email_verified_at
        FROM users
        WHERE raven_id LIKE ?
           OR (allow_display_name_search = 1 AND lower(display_name) LIKE ?)
        ORDER BY display_name ASC
        LIMIT 20
        "#,
    )
    .bind(&like)
    .bind(&like)
    .fetch_all(&state.db)
    .await?;

    let mut users = Vec::with_capacity(rows.len());
    for row in rows {
        users.push(public_user_from_row(&row)?);
    }

    Ok(Json(users))
}

async fn get_user(
    State(state): State<Arc<AppState>>,
    Path(raven_id): Path<String>,
) -> ApiResult<Json<UserPublic>> {
    validate_raven_id(&raven_id)?;

    let row = sqlx::query(
        r#"
        SELECT raven_id, display_name, email_verified_at
        FROM users
        WHERE raven_id = ?
        LIMIT 1
        "#,
    )
    .bind(raven_id)
    .fetch_optional(&state.db)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::NotFound("User not found.".to_string()));
    };

    Ok(Json(public_user_from_row(&row)?))
}

async fn update_my_profile(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<UpdateProfileRequest>,
) -> ApiResult<Json<UserPublic>> {
    let clean_name = req.display_name.trim().to_string();
    validate_display_name(&clean_name)?;

    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    let now = Utc::now().to_rfc3339();

    sqlx::query("UPDATE users SET display_name = ?, updated_at = ? WHERE raven_id = ?")
        .bind(&clean_name)
        .bind(now)
        .bind(&user.raven_id)
        .execute(&state.db)
        .await?;

    let row = sqlx::query(
        r#"
        SELECT raven_id, display_name, email_verified_at
        FROM users
        WHERE raven_id = ?
        LIMIT 1
        "#,
    )
    .bind(&user.raven_id)
    .fetch_one(&state.db)
    .await?;

    Ok(Json(public_user_from_row(&row)?))
}
