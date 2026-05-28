use std::sync::Arc;

use axum::{extract::State, routing::post, Json, Router};
use chrono::Utc;
use sqlx::Row;
use uuid::Uuid;

use crate::{
    error::{ApiError, ApiResult},
    models::{
        AuthResponse, BasicResponse, ForgotPasswordRequest, LoginRequest, RegisterRequest,
        ResetPasswordRequest, UserPublic, VerifyEmailRequest,
    },
    services::{
        auth_service::{
            create_demo_code, create_session, consume_code, email_hash, generate_raven_id,
            hash_password, public_user_from_row, verify_password, DEMO_CODE,
        },
        validation::{
            normalize_email, validate_code, validate_display_name, validate_email, validate_password,
        },
    },
    AppState,
};

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/register", post(register))
        .route("/verify-email", post(verify_email))
        .route("/login", post(login))
        .route("/forgot-password", post(forgot_password))
        .route("/reset-password", post(reset_password))
}

async fn register(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterRequest>,
) -> ApiResult<Json<AuthResponse>> {
    let normalized_email = normalize_email(&req.email);
    validate_email(&normalized_email)?;
    validate_password(&req.password)?;

    let display_name = req
        .display_name
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("Raven User")
        .to_string();
    validate_display_name(&display_name)?;

    let email_hash = email_hash(&normalized_email);
    let existing = sqlx::query("SELECT id FROM users WHERE email_hash = ? LIMIT 1")
        .bind(&email_hash)
        .fetch_optional(&state.db)
        .await?;

    if existing.is_some() {
        return Err(ApiError::Conflict("This email is already in use.".to_string()));
    }

    let password_hash = hash_password(&req.password)?;
    let now = Utc::now().to_rfc3339();
    let user_id = Uuid::new_v4().to_string();

    let mut raven_id = generate_raven_id(&display_name);
    for _ in 0..5 {
        let id_exists = sqlx::query("SELECT id FROM users WHERE raven_id = ? LIMIT 1")
            .bind(&raven_id)
            .fetch_optional(&state.db)
            .await?;

        if id_exists.is_none() {
            break;
        }
        raven_id = generate_raven_id(&display_name);
    }

    sqlx::query(
        r#"
        INSERT INTO users (
            id, raven_id, display_name, email_hash, password_hash,
            email_verified_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?)
        "#,
    )
    .bind(&user_id)
    .bind(&raven_id)
    .bind(&display_name)
    .bind(&email_hash)
    .bind(&password_hash)
    .bind(&now)
    .bind(&now)
    .execute(&state.db)
    .await?;

    create_demo_code(&state.db, &email_hash, "email_verify").await?;

    Ok(Json(AuthResponse {
        user: UserPublic {
            raven_id,
            display_name,
            email_verified: false,
        },
        session_token: None,
        demo_code: state.config.demo_codes_enabled.then(|| DEMO_CODE.to_string()),
    }))
}

async fn verify_email(
    State(state): State<Arc<AppState>>,
    Json(req): Json<VerifyEmailRequest>,
) -> ApiResult<Json<AuthResponse>> {
    let normalized_email = normalize_email(&req.email);
    validate_email(&normalized_email)?;
    validate_code(&req.code)?;

    let email_hash = email_hash(&normalized_email);
    consume_code(&state.db, &email_hash, "email_verify", &req.code).await?;

    let now = Utc::now().to_rfc3339();
    sqlx::query("UPDATE users SET email_verified_at = ?, updated_at = ? WHERE email_hash = ?")
        .bind(&now)
        .bind(&now)
        .bind(&email_hash)
        .execute(&state.db)
        .await?;

    let row = sqlx::query(
        "SELECT id, raven_id, display_name, email_verified_at FROM users WHERE email_hash = ? LIMIT 1",
    )
    .bind(&email_hash)
    .fetch_one(&state.db)
    .await?;

    let user_id: String = row.try_get("id")?;
    let session_token = create_session(&state.db, &user_id).await?;
    let user = public_user_from_row(&row)?;

    Ok(Json(AuthResponse {
        user,
        session_token: Some(session_token),
        demo_code: None,
    }))
}

async fn login(
    State(state): State<Arc<AppState>>,
    Json(req): Json<LoginRequest>,
) -> ApiResult<Json<AuthResponse>> {
    let normalized_email = normalize_email(&req.email);
    validate_email(&normalized_email)?;
    validate_password(&req.password)?;

    let email_hash = email_hash(&normalized_email);
    let row = sqlx::query(
        r#"
        SELECT id, raven_id, display_name, email_verified_at, password_hash
        FROM users
        WHERE email_hash = ?
        LIMIT 1
        "#,
    )
    .bind(&email_hash)
    .fetch_optional(&state.db)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::Unauthorized("Invalid email or password.".to_string()));
    };

    let password_hash: String = row.try_get("password_hash")?;
    if !verify_password(&req.password, &password_hash) {
        return Err(ApiError::Unauthorized("Invalid email or password.".to_string()));
    }

    let verified_at: Option<String> = row.try_get("email_verified_at")?;
    if verified_at.is_none() {
        return Err(ApiError::Forbidden("Email is not verified.".to_string()));
    }

    let user_id: String = row.try_get("id")?;
    let session_token = create_session(&state.db, &user_id).await?;
    let user = public_user_from_row(&row)?;

    Ok(Json(AuthResponse {
        user,
        session_token: Some(session_token),
        demo_code: None,
    }))
}

async fn forgot_password(
    State(state): State<Arc<AppState>>,
    Json(req): Json<ForgotPasswordRequest>,
) -> ApiResult<Json<BasicResponse>> {
    let normalized_email = normalize_email(&req.email);
    validate_email(&normalized_email)?;

    let email_hash = email_hash(&normalized_email);
    let exists = sqlx::query("SELECT id FROM users WHERE email_hash = ? LIMIT 1")
        .bind(&email_hash)
        .fetch_optional(&state.db)
        .await?
        .is_some();

    if exists {
        create_demo_code(&state.db, &email_hash, "password_reset").await?;
    }

    // Privacy-safe response: do not reveal whether the email exists.
    Ok(Json(BasicResponse {
        ok: true,
        message: "If this account exists, a recovery code was sent.".to_string(),
        demo_code: state.config.demo_codes_enabled.then(|| DEMO_CODE.to_string()),
    }))
}

async fn reset_password(
    State(state): State<Arc<AppState>>,
    Json(req): Json<ResetPasswordRequest>,
) -> ApiResult<Json<BasicResponse>> {
    let normalized_email = normalize_email(&req.email);
    validate_email(&normalized_email)?;
    validate_code(&req.code)?;
    validate_password(&req.new_password)?;

    let email_hash = email_hash(&normalized_email);
    consume_code(&state.db, &email_hash, "password_reset", &req.code).await?;

    let password_hash = hash_password(&req.new_password)?;
    let now = Utc::now().to_rfc3339();
    let result = sqlx::query("UPDATE users SET password_hash = ?, updated_at = ? WHERE email_hash = ?")
        .bind(password_hash)
        .bind(now)
        .bind(email_hash)
        .execute(&state.db)
        .await?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Account not found.".to_string()));
    }

    Ok(Json(BasicResponse {
        ok: true,
        message: "Password reset successfully.".to_string(),
        demo_code: None,
    }))
}
