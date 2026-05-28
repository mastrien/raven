use crate::error::{ApiError, ApiResult};

pub fn normalize_email(email: &str) -> String {
    email.trim().to_lowercase()
}

pub fn validate_email(email: &str) -> ApiResult<()> {
    if email.is_empty() {
        return Err(ApiError::BadRequest("Email is required.".to_string()));
    }

    if email.len() > 254 {
        return Err(ApiError::BadRequest("Email is too long.".to_string()));
    }

    let has_spaces = email.chars().any(char::is_whitespace);
    let at_count = email.matches('@').count();
    let has_basic_domain = email
        .split('@')
        .nth(1)
        .map(|domain| domain.contains('.') && !domain.starts_with('.') && !domain.ends_with('.'))
        .unwrap_or(false);

    if has_spaces || at_count != 1 || !has_basic_domain || email.starts_with('@') {
        return Err(ApiError::BadRequest("Invalid email format.".to_string()));
    }

    Ok(())
}

pub fn validate_password(password: &str) -> ApiResult<()> {
    if password.is_empty() {
        return Err(ApiError::BadRequest("Password is required.".to_string()));
    }

    if password.len() < 8 {
        return Err(ApiError::BadRequest("Password must have at least 8 characters.".to_string()));
    }

    if password.len() > 128 {
        return Err(ApiError::BadRequest("Password is too long.".to_string()));
    }

    Ok(())
}

pub fn validate_display_name(display_name: &str) -> ApiResult<()> {
    if display_name.trim().is_empty() {
        return Err(ApiError::BadRequest("Display name is required.".to_string()));
    }

    if display_name.chars().count() > 40 {
        return Err(ApiError::BadRequest("Display name is too long.".to_string()));
    }

    Ok(())
}

pub fn validate_code(code: &str) -> ApiResult<()> {
    if code.len() != 6 || !code.chars().all(|c| c.is_ascii_digit()) {
        return Err(ApiError::BadRequest("Code must be 6 digits.".to_string()));
    }

    Ok(())
}

pub fn validate_raven_id(raven_id: &str) -> ApiResult<()> {
    if raven_id.is_empty() {
        return Err(ApiError::BadRequest("Raven ID is required.".to_string()));
    }

    if raven_id.len() > 48 {
        return Err(ApiError::BadRequest("Raven ID is too long.".to_string()));
    }

    if !raven_id.starts_with("rvn_") {
        return Err(ApiError::BadRequest("Invalid Raven ID format.".to_string()));
    }

    if !raven_id
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
    {
        return Err(ApiError::BadRequest("Invalid Raven ID format.".to_string()));
    }

    Ok(())
}


pub fn validate_group_name(name: &str) -> ApiResult<()> {
    let clean = name.trim();
    if clean.is_empty() {
        return Err(ApiError::BadRequest("Group name is required.".to_string()));
    }
    if clean.chars().count() > 40 {
        return Err(ApiError::BadRequest("Group name is too long.".to_string()));
    }
    Ok(())
}
