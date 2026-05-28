use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::{Duration, Utc};
use sha2::{Digest, Sha256};
use sqlx::{Row, SqlitePool};
use uuid::Uuid;

use crate::{
    error::{ApiError, ApiResult},
    models::{AuthenticatedUser, UserPublic},
};

pub const DEMO_CODE: &str = "123456";

pub fn sha256_hex(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    hex::encode(hasher.finalize())
}

pub fn email_hash(normalized_email: &str) -> String {
    sha256_hex(normalized_email)
}

pub fn code_hash(email_hash: &str, purpose: &str, code: &str) -> String {
    sha256_hex(&format!("{email_hash}:{purpose}:{code}"))
}

pub fn hash_password(password: &str) -> ApiResult<String> {
    let salt = SaltString::generate(&mut OsRng);
    let hash = Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map_err(|err| ApiError::Internal(format!("Failed to hash password: {err}")))?;

    Ok(hash.to_string())
}

pub fn verify_password(password: &str, stored_hash: &str) -> bool {
    let Ok(parsed_hash) = PasswordHash::new(stored_hash) else {
        return false;
    };

    Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .is_ok()
}

pub fn generate_raven_id(display_name: &str) -> String {
    let mut slug = display_name
        .trim()
        .to_lowercase()
        .chars()
        .filter_map(|ch| {
            if ch.is_ascii_alphanumeric() {
                Some(ch)
            } else if ch.is_whitespace() || ch == '-' || ch == '_' {
                Some('_')
            } else {
                None
            }
        })
        .collect::<String>();

    while slug.contains("__") {
        slug = slug.replace("__", "_");
    }

    let slug = slug.trim_matches('_');
    let base = if slug.is_empty() { "user" } else { slug };
    let base = base.chars().take(16).collect::<String>();
    let suffix = Uuid::new_v4().simple().to_string()[..6].to_uppercase();

    format!("rvn_{base}_{suffix}")
}

pub async fn create_demo_code(pool: &SqlitePool, email_hash: &str, purpose: &str) -> ApiResult<()> {
    let now = Utc::now();
    let expires_at = now + Duration::minutes(15);
    let id = Uuid::new_v4().to_string();
    let code_hash = code_hash(email_hash, purpose, DEMO_CODE);

    sqlx::query(
        r#"
        INSERT INTO verification_codes (id, email_hash, purpose, code_hash, expires_at, consumed_at, created_at)
        VALUES (?, ?, ?, ?, ?, NULL, ?)
        "#,
    )
    .bind(id)
    .bind(email_hash)
    .bind(purpose)
    .bind(code_hash)
    .bind(expires_at.to_rfc3339())
    .bind(now.to_rfc3339())
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn consume_code(pool: &SqlitePool, email_hash: &str, purpose: &str, code: &str) -> ApiResult<()> {
    let now = Utc::now().to_rfc3339();
    let expected_hash = code_hash(email_hash, purpose, code);

    let row = sqlx::query(
        r#"
        SELECT id
        FROM verification_codes
        WHERE email_hash = ?
          AND purpose = ?
          AND code_hash = ?
          AND consumed_at IS NULL
          AND expires_at > ?
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(email_hash)
    .bind(purpose)
    .bind(expected_hash)
    .bind(&now)
    .fetch_optional(pool)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::BadRequest("Invalid or expired code.".to_string()));
    };

    let id: String = row.try_get("id")?;
    sqlx::query("UPDATE verification_codes SET consumed_at = ? WHERE id = ?")
        .bind(now)
        .bind(id)
        .execute(pool)
        .await?;

    Ok(())
}

pub async fn create_session(pool: &SqlitePool, user_id: &str) -> ApiResult<String> {
    let token = format!("rvn_sess_{}{}", Uuid::new_v4().simple(), Uuid::new_v4().simple());
    let token_hash = sha256_hex(&token);
    let now = Utc::now();
    let expires_at = now + Duration::days(30);

    sqlx::query(
        r#"
        INSERT INTO sessions (id, user_id, token_hash, created_at, expires_at)
        VALUES (?, ?, ?, ?, ?)
        "#,
    )
    .bind(Uuid::new_v4().to_string())
    .bind(user_id)
    .bind(token_hash)
    .bind(now.to_rfc3339())
    .bind(expires_at.to_rfc3339())
    .execute(pool)
    .await?;

    Ok(token)
}

pub async fn authenticate_token(pool: &SqlitePool, token: &str) -> ApiResult<AuthenticatedUser> {
    if token.trim().is_empty() {
        return Err(ApiError::Unauthorized("Missing session token.".to_string()));
    }

    let token_hash = sha256_hex(token.trim());
    let now = Utc::now().to_rfc3339();

    let row = sqlx::query(
        r#"
        SELECT users.raven_id
        FROM sessions
        INNER JOIN users ON users.id = sessions.user_id
        WHERE sessions.token_hash = ?
          AND sessions.expires_at > ?
        LIMIT 1
        "#,
    )
    .bind(token_hash)
    .bind(now)
    .fetch_optional(pool)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::Unauthorized("Invalid or expired session token.".to_string()));
    };

    Ok(AuthenticatedUser {
        raven_id: row.try_get("raven_id")?,
    })
}

pub fn public_user_from_row(row: &sqlx::sqlite::SqliteRow) -> ApiResult<UserPublic> {
    let verified_at: Option<String> = row.try_get("email_verified_at")?;

    Ok(UserPublic {
        raven_id: row.try_get("raven_id")?,
        display_name: row.try_get("display_name")?,
        email_verified: verified_at.is_some(),
    })
}
