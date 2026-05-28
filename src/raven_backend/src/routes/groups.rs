use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, patch, post},
    Json, Router,
};
use chrono::Utc;
use sqlx::Row;
use uuid::Uuid;

use crate::{
    error::{ApiError, ApiResult},
    models::{
        AddGroupMemberRequest, CreateGroupRequest, GroupInviteResponse, GroupMessageResponse,
        GroupResponse, RenameGroupRequest, RespondGroupInviteRequest, SearchQuery, SendGroupMessageRequest,
    },
    services::{
        auth_service::authenticate_token,
        validation::{validate_group_name, validate_raven_id},
    },
    AppState,
};

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/groups", post(create_group))
        .route("/groups/search", get(search_groups))
        .route("/groups/mine/:raven_id", get(my_groups))
        .route("/groups/by-id/:group_id", get(get_group))
        .route("/groups/:group_id/rename", patch(rename_group))
        .route("/groups/:group_id/leave", post(leave_group))
        .route("/groups/:group_id/close", post(close_group))
        .route("/groups/:group_id/members", post(add_member))
        .route("/groups/:group_id/messages", post(send_group_message))
        .route("/groups/inbox/:raven_id", get(group_inbox))
        .route("/groups/messages/:message_id/delivered", post(mark_group_message_delivered))
        .route("/groups/invites/:raven_id", get(group_invites))
        .route("/groups/:group_id/invites/respond", post(respond_group_invite))
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

fn group_from_row(
    row: &sqlx::sqlite::SqliteRow,
    member_ids: Vec<String>,
    invited_ids: Vec<String>,
    my_status: Option<String>,
) -> ApiResult<GroupResponse> {
    let status = row.try_get::<String, _>("status");
    Ok(GroupResponse {
        id: row.try_get("id")?,
        client_group_id: row.try_get("client_group_id")?,
        name: row.try_get("name")?,
        owner_raven_id: row.try_get("owner_raven_id")?,
        member_raven_ids: member_ids,
        invited_raven_ids: invited_ids,
        status: status.unwrap_or_else(|_| "active".to_string()),
        my_status,
        created_at: row.try_get("created_at")?,
    })
}

async fn member_lists(state: &AppState, group_id: &str) -> ApiResult<(Vec<String>, Vec<String>)> {
    let rows = sqlx::query(
        r#"
        SELECT raven_id, status
        FROM group_members
        WHERE group_id = ?
        ORDER BY added_at ASC
        "#,
    )
    .bind(group_id)
    .fetch_all(&state.db)
    .await?;

    let mut members = Vec::new();
    let mut invited = Vec::new();
    for row in rows {
        let raven_id: String = row.try_get("raven_id")?;
        let status: String = row.try_get("status")?;
        if status == "accepted" {
            members.push(raven_id);
        } else if status == "invited" {
            invited.push(raven_id);
        }
    }
    Ok((members, invited))
}

async fn my_membership_status(state: &AppState, group_id: &str, viewer: Option<&str>) -> ApiResult<Option<String>> {
    let Some(viewer) = viewer else { return Ok(None); };
    let row = sqlx::query("SELECT status FROM group_members WHERE group_id = ? AND raven_id = ? LIMIT 1")
        .bind(group_id)
        .bind(viewer)
        .fetch_optional(&state.db)
        .await?;
    Ok(row.map(|row| row.try_get::<String, _>("status")).transpose()?)
}

async fn group_response(state: &AppState, group_id: &str, viewer: Option<&str>) -> ApiResult<GroupResponse> {
    let row = sqlx::query(
        r#"
        SELECT id, client_group_id, name, owner_raven_id, status, created_at
        FROM groups
        WHERE id = ?
        LIMIT 1
        "#,
    )
    .bind(group_id)
    .fetch_optional(&state.db)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::NotFound("Group not found.".to_string()));
    };

    let (members, invited) = member_lists(state, group_id).await?;
    let my_status = my_membership_status(state, group_id, viewer).await?;
    group_from_row(&row, members, invited, my_status)
}

async fn ensure_user_exists(state: &AppState, raven_id: &str) -> ApiResult<()> {
    validate_raven_id(raven_id)?;
    let exists = sqlx::query("SELECT id FROM users WHERE raven_id = ? LIMIT 1")
        .bind(raven_id)
        .fetch_optional(&state.db)
        .await?
        .is_some();
    if !exists {
        return Err(ApiError::NotFound("User not found.".to_string()));
    }
    Ok(())
}

async fn display_name_for_user(state: &AppState, raven_id: &str) -> ApiResult<String> {
    let row = sqlx::query("SELECT display_name FROM users WHERE raven_id = ? LIMIT 1")
        .bind(raven_id)
        .fetch_optional(&state.db)
        .await?;
    Ok(row
        .map(|row| row.try_get::<String, _>("display_name"))
        .transpose()?
        .unwrap_or_else(|| raven_id.to_string()))
}

async fn membership_status_for_user(state: &AppState, raven_id: &str) -> ApiResult<String> {
    let row = sqlx::query("SELECT group_add_policy FROM users WHERE raven_id = ? LIMIT 1")
        .bind(raven_id)
        .fetch_optional(&state.db)
        .await?;

    let Some(row) = row else {
        return Err(ApiError::NotFound("User not found.".to_string()));
    };

    let policy: String = row.try_get("group_add_policy")?;
    if policy == "everyone" {
        Ok("accepted".to_string())
    } else {
        Ok("invited".to_string())
    }
}

async fn upsert_group_member(state: &AppState, group_id: &str, raven_id: &str, role: &str, status: &str) -> ApiResult<()> {
    let now = Utc::now().to_rfc3339();
    sqlx::query(
        r#"
        INSERT INTO group_members (group_id, raven_id, role, status, added_at, responded_at)
        VALUES (?, ?, ?, ?, ?, NULL)
        ON CONFLICT(group_id, raven_id)
        DO UPDATE SET role = excluded.role, status = excluded.status, responded_at = NULL
        "#,
    )
    .bind(group_id)
    .bind(raven_id)
    .bind(role)
    .bind(status)
    .bind(now)
    .execute(&state.db)
    .await?;
    Ok(())
}

async fn create_system_event(state: &AppState, group_id: &str, actor_raven_id: &str, text: &str) -> ApiResult<()> {
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    sqlx::query(
        r#"
        INSERT INTO group_messages (id, client_message_id, group_id, sender_raven_id, encrypted_payload, message_kind, created_at)
        VALUES (?, NULL, ?, ?, ?, 'system_event', ?)
        "#,
    )
    .bind(id)
    .bind(group_id)
    .bind(actor_raven_id)
    .bind(text.trim())
    .bind(&now)
    .execute(&state.db)
    .await?;
    sqlx::query("UPDATE groups SET updated_at = ? WHERE id = ?")
        .bind(now)
        .bind(group_id)
        .execute(&state.db)
        .await?;
    Ok(())
}

async fn require_admin(state: &AppState, group_id: &str, raven_id: &str) -> ApiResult<String> {
    let row = sqlx::query(
        "SELECT role, status FROM group_members WHERE group_id = ? AND raven_id = ? LIMIT 1",
    )
    .bind(group_id)
    .bind(raven_id)
    .fetch_optional(&state.db)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::Forbidden("You are not a member of this group.".to_string()));
    };
    let role: String = row.try_get("role")?;
    let status: String = row.try_get("status")?;
    if status != "accepted" || !(role == "owner" || role == "admin") {
        return Err(ApiError::Forbidden("Only accepted admins can change this group.".to_string()));
    }
    Ok(role)
}

async fn create_group(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<CreateGroupRequest>,
) -> ApiResult<Json<GroupResponse>> {
    validate_group_name(&req.name)?;
    validate_raven_id(&req.owner_raven_id)?;

    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    if user.raven_id != req.owner_raven_id {
        return Err(ApiError::Forbidden("Owner does not match session user.".to_string()));
    }

    ensure_user_exists(&state, &req.owner_raven_id).await?;

    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    let clean_name = req.name.trim().to_string();

    sqlx::query(
        r#"
        INSERT INTO groups (id, client_group_id, name, owner_raven_id, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, 'active', ?, ?)
        "#,
    )
    .bind(&id)
    .bind(&req.client_group_id)
    .bind(&clean_name)
    .bind(&req.owner_raven_id)
    .bind(&now)
    .bind(&now)
    .execute(&state.db)
    .await?;

    upsert_group_member(&state, &id, &req.owner_raven_id, "owner", "accepted").await?;

    let mut seen = vec![req.owner_raven_id.to_lowercase()];
    for member in req.member_raven_ids {
        let clean = member.trim().to_string();
        if clean.is_empty() || seen.iter().any(|id| id == &clean.to_lowercase()) {
            continue;
        }
        ensure_user_exists(&state, &clean).await?;
        let status = membership_status_for_user(&state, &clean).await?;
        upsert_group_member(&state, &id, &clean, "member", &status).await?;
        let actor_name = display_name_for_user(&state, &req.owner_raven_id).await?;
        let target_name = display_name_for_user(&state, &clean).await?;
        let event = if status == "accepted" {
            format!("{actor_name} added {target_name} to the group.")
        } else {
            format!("{actor_name} invited {target_name} to the group.")
        };
        create_system_event(&state, &id, &req.owner_raven_id, &event).await?;
        seen.push(clean.to_lowercase());
    }

    Ok(Json(group_response(&state, &id, Some(&user.raven_id)).await?))
}

async fn get_group(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(group_id): Path<String>,
) -> ApiResult<Json<GroupResponse>> {
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;

    let membership = sqlx::query(
        "SELECT status FROM group_members WHERE group_id = ? AND raven_id = ? LIMIT 1",
    )
    .bind(&group_id)
    .bind(&user.raven_id)
    .fetch_optional(&state.db)
    .await?;

    if membership.is_none() {
        return Err(ApiError::Forbidden("You are not a member of this group.".to_string()));
    }

    Ok(Json(group_response(&state, &group_id, Some(&user.raven_id)).await?))
}

async fn search_groups(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Query(query): Query<SearchQuery>,
) -> ApiResult<Json<Vec<GroupResponse>>> {
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    let q = query.q.unwrap_or_default().trim().to_string();

    if q.len() > 64 {
        return Err(ApiError::BadRequest("Search query is too long.".to_string()));
    }

    let like = format!("%{}%", q.to_lowercase());
    let rows = sqlx::query(
        r#"
        SELECT groups.id, groups.client_group_id, groups.name, groups.owner_raven_id, groups.status, groups.created_at
        FROM groups
        INNER JOIN group_members ON group_members.group_id = groups.id
        WHERE group_members.raven_id = ?
          AND group_members.status = 'accepted'
          AND groups.status = 'active'
          AND (? = '%%' OR lower(groups.name) LIKE ?)
        ORDER BY groups.updated_at DESC
        LIMIT 30
        "#,
    )
    .bind(&user.raven_id)
    .bind(&like)
    .bind(&like)
    .fetch_all(&state.db)
    .await?;

    let mut response = Vec::new();
    for row in rows {
        let group_id: String = row.try_get("id")?;
        let (members, invited) = member_lists(&state, &group_id).await?;
        let my_status = my_membership_status(&state, &group_id, Some(&user.raven_id)).await?;
        response.push(group_from_row(&row, members, invited, my_status)?);
    }
    Ok(Json(response))
}

async fn my_groups(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(raven_id): Path<String>,
) -> ApiResult<Json<Vec<GroupResponse>>> {
    validate_raven_id(&raven_id)?;
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    if user.raven_id != raven_id {
        return Err(ApiError::Forbidden("You can only fetch your own groups.".to_string()));
    }

    let rows = sqlx::query(
        r#"
        SELECT groups.id, groups.client_group_id, groups.name, groups.owner_raven_id, groups.status, groups.created_at
        FROM groups
        INNER JOIN group_members ON group_members.group_id = groups.id
        WHERE group_members.raven_id = ?
          AND group_members.status IN ('accepted', 'left')
        ORDER BY groups.updated_at DESC
        LIMIT 100
        "#,
    )
    .bind(&raven_id)
    .fetch_all(&state.db)
    .await?;

    let mut response = Vec::new();
    for row in rows {
        let group_id: String = row.try_get("id")?;
        let (members, invited) = member_lists(&state, &group_id).await?;
        let my_status = my_membership_status(&state, &group_id, Some(&raven_id)).await?;
        response.push(group_from_row(&row, members, invited, my_status)?);
    }
    Ok(Json(response))
}

async fn add_member(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(group_id): Path<String>,
    Json(req): Json<AddGroupMemberRequest>,
) -> ApiResult<Json<GroupResponse>> {
    validate_raven_id(&req.member_raven_id)?;
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;

    let group_row = sqlx::query("SELECT status FROM groups WHERE id = ? LIMIT 1")
        .bind(&group_id)
        .fetch_optional(&state.db)
        .await?;
    let Some(group_row) = group_row else {
        return Err(ApiError::NotFound("Group not found.".to_string()));
    };
    let group_status: String = group_row.try_get("status")?;
    if group_status != "active" {
        return Err(ApiError::Forbidden("This group is closed.".to_string()));
    }

    require_admin(&state, &group_id, &user.raven_id).await?;
    ensure_user_exists(&state, &req.member_raven_id).await?;

    let existing = sqlx::query("SELECT status FROM group_members WHERE group_id = ? AND raven_id = ? LIMIT 1")
        .bind(&group_id)
        .bind(&req.member_raven_id)
        .fetch_optional(&state.db)
        .await?;
    if let Some(existing) = existing {
        let status: String = existing.try_get("status")?;
        if status == "accepted" || status == "invited" {
            return Err(ApiError::BadRequest("This user is already in this group.".to_string()));
        }
    }

    let member_status = membership_status_for_user(&state, &req.member_raven_id).await?;
    upsert_group_member(&state, &group_id, &req.member_raven_id, "member", &member_status).await?;

    let actor_name = display_name_for_user(&state, &user.raven_id).await?;
    let target_name = display_name_for_user(&state, &req.member_raven_id).await?;
    let event = if member_status == "accepted" {
        format!("{actor_name} added {target_name} to the group.")
    } else {
        format!("{actor_name} invited {target_name} to the group.")
    };
    create_system_event(&state, &group_id, &user.raven_id, &event).await?;

    Ok(Json(group_response(&state, &group_id, Some(&user.raven_id)).await?))
}

async fn rename_group(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(group_id): Path<String>,
    Json(req): Json<RenameGroupRequest>,
) -> ApiResult<Json<GroupResponse>> {
    validate_group_name(&req.name)?;
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    require_admin(&state, &group_id, &user.raven_id).await?;

    let row = sqlx::query("SELECT name, status FROM groups WHERE id = ? LIMIT 1")
        .bind(&group_id)
        .fetch_optional(&state.db)
        .await?;
    let Some(row) = row else { return Err(ApiError::NotFound("Group not found.".to_string())); };
    let old_name: String = row.try_get("name")?;
    let group_status: String = row.try_get("status")?;
    if group_status != "active" {
        return Err(ApiError::Forbidden("This group is closed.".to_string()));
    }

    let clean_name = req.name.trim().to_string();
    let now = Utc::now().to_rfc3339();
    sqlx::query("UPDATE groups SET name = ?, updated_at = ? WHERE id = ?")
        .bind(&clean_name)
        .bind(&now)
        .bind(&group_id)
        .execute(&state.db)
        .await?;

    if old_name != clean_name {
        let actor_name = display_name_for_user(&state, &user.raven_id).await?;
        create_system_event(
            &state,
            &group_id,
            &user.raven_id,
            &format!("{actor_name} changed the group name from \"{old_name}\" to \"{clean_name}\"."),
        )
        .await?;
    }

    Ok(Json(group_response(&state, &group_id, Some(&user.raven_id)).await?))
}

async fn leave_group(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(group_id): Path<String>,
) -> ApiResult<Json<GroupResponse>> {
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    let now = Utc::now().to_rfc3339();

    let group_row = sqlx::query("SELECT owner_raven_id, status FROM groups WHERE id = ? LIMIT 1")
        .bind(&group_id)
        .fetch_optional(&state.db)
        .await?;
    let Some(group_row) = group_row else { return Err(ApiError::NotFound("Group not found.".to_string())); };
    let owner_raven_id: String = group_row.try_get("owner_raven_id")?;
    let group_status: String = group_row.try_get("status")?;
    if group_status != "active" {
        return Err(ApiError::Forbidden("This group is already closed.".to_string()));
    }

    let member_row = sqlx::query("SELECT role, status FROM group_members WHERE group_id = ? AND raven_id = ? LIMIT 1")
        .bind(&group_id)
        .bind(&user.raven_id)
        .fetch_optional(&state.db)
        .await?;
    let Some(member_row) = member_row else { return Err(ApiError::Forbidden("You are not a member of this group.".to_string())); };
    let member_status: String = member_row.try_get("status")?;
    if member_status != "accepted" {
        return Err(ApiError::BadRequest("You are not an active member of this group.".to_string()));
    }

    let accepted_rows = sqlx::query(
        "SELECT raven_id, role, added_at FROM group_members WHERE group_id = ? AND status = 'accepted' ORDER BY added_at ASC",
    )
    .bind(&group_id)
    .fetch_all(&state.db)
    .await?;

    if owner_raven_id == user.raven_id {
        if accepted_rows.len() <= 1 {
            sqlx::query("UPDATE groups SET status = 'closed', closed_at = ?, updated_at = ? WHERE id = ?")
                .bind(&now)
                .bind(&now)
                .bind(&group_id)
                .execute(&state.db)
                .await?;
            sqlx::query("UPDATE group_members SET status = 'left', responded_at = ? WHERE group_id = ? AND status = 'accepted'")
                .bind(&now)
                .bind(&group_id)
                .execute(&state.db)
                .await?;
            let actor_name = display_name_for_user(&state, &user.raven_id).await?;
            create_system_event(&state, &group_id, &user.raven_id, &format!("{actor_name} closed the group."))
                .await?;
            return Ok(Json(group_response(&state, &group_id, Some(&user.raven_id)).await?));
        }

        let mut next_owner: Option<String> = None;
        for row in &accepted_rows {
            let raven_id: String = row.try_get("raven_id")?;
            let role: String = row.try_get("role")?;
            if raven_id != user.raven_id && role == "admin" {
                next_owner = Some(raven_id);
                break;
            }
        }

        let Some(next_owner) = next_owner else {
            return Err(ApiError::Forbidden("Promote another member to admin before leaving this group.".to_string()));
        };

        sqlx::query("UPDATE groups SET owner_raven_id = ?, updated_at = ? WHERE id = ?")
            .bind(&next_owner)
            .bind(&now)
            .bind(&group_id)
            .execute(&state.db)
            .await?;
        sqlx::query("UPDATE group_members SET role = 'owner' WHERE group_id = ? AND raven_id = ?")
            .bind(&group_id)
            .bind(&next_owner)
            .execute(&state.db)
            .await?;
    }

    sqlx::query("UPDATE group_members SET status = 'left', responded_at = ?, role = CASE WHEN role = 'owner' THEN 'member' ELSE role END WHERE group_id = ? AND raven_id = ?")
        .bind(&now)
        .bind(&group_id)
        .bind(&user.raven_id)
        .execute(&state.db)
        .await?;

    let actor_name = display_name_for_user(&state, &user.raven_id).await?;
    if owner_raven_id == user.raven_id {
        let new_owner = sqlx::query("SELECT owner_raven_id FROM groups WHERE id = ? LIMIT 1")
            .bind(&group_id)
            .fetch_one(&state.db)
            .await?
            .try_get::<String, _>("owner_raven_id")?;
        let owner_name = display_name_for_user(&state, &new_owner).await?;
        create_system_event(
            &state,
            &group_id,
            &user.raven_id,
            &format!("{actor_name} left the group. {owner_name} is now the owner."),
        )
        .await?;
    } else {
        create_system_event(&state, &group_id, &user.raven_id, &format!("{actor_name} left the group."))
            .await?;
    }

    Ok(Json(group_response(&state, &group_id, Some(&user.raven_id)).await?))
}

async fn close_group(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(group_id): Path<String>,
) -> ApiResult<Json<GroupResponse>> {
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    require_admin(&state, &group_id, &user.raven_id).await?;

    let now = Utc::now().to_rfc3339();
    sqlx::query("UPDATE groups SET status = 'closed', closed_at = ?, updated_at = ? WHERE id = ?")
        .bind(&now)
        .bind(&now)
        .bind(&group_id)
        .execute(&state.db)
        .await?;
    sqlx::query("UPDATE group_members SET status = 'left', responded_at = ? WHERE group_id = ? AND status = 'accepted'")
        .bind(&now)
        .bind(&group_id)
        .execute(&state.db)
        .await?;

    let actor_name = display_name_for_user(&state, &user.raven_id).await?;
    create_system_event(&state, &group_id, &user.raven_id, &format!("{actor_name} closed the group."))
        .await?;

    Ok(Json(group_response(&state, &group_id, Some(&user.raven_id)).await?))
}

async fn group_invites(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(raven_id): Path<String>,
) -> ApiResult<Json<Vec<GroupInviteResponse>>> {
    validate_raven_id(&raven_id)?;
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    if user.raven_id != raven_id {
        return Err(ApiError::Forbidden("You can only fetch your own group invites.".to_string()));
    }

    let rows = sqlx::query(
        r#"
        SELECT group_members.group_id, groups.name, groups.owner_raven_id, group_members.added_at
        FROM group_members
        INNER JOIN groups ON groups.id = group_members.group_id
        WHERE group_members.raven_id = ?
          AND group_members.status = 'invited'
          AND groups.status = 'active'
        ORDER BY group_members.added_at DESC
        LIMIT 50
        "#,
    )
    .bind(&raven_id)
    .fetch_all(&state.db)
    .await?;

    let mut invites = Vec::new();
    for row in rows {
        invites.push(GroupInviteResponse {
            group_id: row.try_get("group_id")?,
            group_name: row.try_get("name")?,
            inviter_raven_id: row.try_get("owner_raven_id")?,
            created_at: row.try_get("added_at")?,
        });
    }
    Ok(Json(invites))
}

async fn respond_group_invite(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(group_id): Path<String>,
    Json(req): Json<RespondGroupInviteRequest>,
) -> ApiResult<Json<GroupResponse>> {
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    let clean_response = req.response.trim().to_lowercase();
    if clean_response != "accept" && clean_response != "decline" {
        return Err(ApiError::BadRequest("Use response = accept or decline.".to_string()));
    }

    let status = if clean_response == "accept" { "accepted" } else { "declined" };
    let now = Utc::now().to_rfc3339();
    let result = sqlx::query(
        "UPDATE group_members SET status = ?, responded_at = ? WHERE group_id = ? AND raven_id = ? AND status = 'invited'",
    )
    .bind(status)
    .bind(&now)
    .bind(&group_id)
    .bind(&user.raven_id)
    .execute(&state.db)
    .await?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Pending invite not found.".to_string()));
    }

    if clean_response == "accept" {
        let actor_name = display_name_for_user(&state, &user.raven_id).await?;
        create_system_event(&state, &group_id, &user.raven_id, &format!("{actor_name} joined the group."))
            .await?;
    }

    Ok(Json(group_response(&state, &group_id, Some(&user.raven_id)).await?))
}

async fn send_group_message(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(group_id): Path<String>,
    Json(req): Json<SendGroupMessageRequest>,
) -> ApiResult<Json<GroupMessageResponse>> {
    validate_raven_id(&req.sender_raven_id)?;
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

    let membership = sqlx::query(
        r#"
        SELECT group_members.status AS member_status, groups.status AS group_status, groups.name AS group_name
        FROM group_members
        INNER JOIN groups ON groups.id = group_members.group_id
        WHERE group_members.group_id = ? AND group_members.raven_id = ?
        LIMIT 1
        "#,
    )
    .bind(&group_id)
    .bind(&user.raven_id)
    .fetch_optional(&state.db)
    .await?;
    let Some(membership) = membership else {
        return Err(ApiError::Forbidden("You are not a member of this group.".to_string()));
    };
    let member_status: String = membership.try_get("member_status")?;
    let group_status: String = membership.try_get("group_status")?;
    if group_status != "active" {
        return Err(ApiError::Forbidden("This group is closed.".to_string()));
    }
    if member_status != "accepted" {
        return Err(ApiError::Forbidden("You are no longer an active member of this group.".to_string()));
    }
    let group_name: String = membership.try_get("group_name")?;

    let id = Uuid::new_v4().to_string();
    let created_at = Utc::now().to_rfc3339();
    sqlx::query(
        r#"
        INSERT INTO group_messages (id, client_message_id, group_id, sender_raven_id, encrypted_payload, message_kind, created_at)
        VALUES (?, ?, ?, ?, ?, 'user_message', ?)
        "#,
    )
    .bind(&id)
    .bind(&req.client_message_id)
    .bind(&group_id)
    .bind(&req.sender_raven_id)
    .bind(&req.encrypted_payload)
    .bind(&created_at)
    .execute(&state.db)
    .await?;

    sqlx::query("UPDATE groups SET updated_at = ? WHERE id = ?")
        .bind(&created_at)
        .bind(&group_id)
        .execute(&state.db)
        .await?;

    Ok(Json(GroupMessageResponse {
        id,
        client_message_id: req.client_message_id,
        group_id,
        group_name,
        sender_raven_id: req.sender_raven_id,
        encrypted_payload: req.encrypted_payload,
        message_kind: "user_message".to_string(),
        created_at,
        delivered_at: None,
    }))
}

async fn group_inbox(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(raven_id): Path<String>,
) -> ApiResult<Json<Vec<GroupMessageResponse>>> {
    validate_raven_id(&raven_id)?;
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;
    if user.raven_id != raven_id {
        return Err(ApiError::Forbidden("You can only fetch your own group inbox.".to_string()));
    }

    let rows = sqlx::query(
        r#"
        SELECT group_messages.id, group_messages.client_message_id, group_messages.group_id,
               groups.name AS group_name, group_messages.sender_raven_id,
               group_messages.encrypted_payload, group_messages.message_kind, group_messages.created_at,
               group_message_deliveries.delivered_at
        FROM group_messages
        INNER JOIN groups ON groups.id = group_messages.group_id
        INNER JOIN group_members ON group_members.group_id = group_messages.group_id
        LEFT JOIN group_message_deliveries
          ON group_message_deliveries.message_id = group_messages.id
         AND group_message_deliveries.raven_id = ?
        WHERE group_members.raven_id = ?
          AND group_members.status = 'accepted'
          AND groups.status = 'active'
          AND (group_messages.sender_raven_id != ? OR group_messages.message_kind = 'system_event')
          AND group_message_deliveries.delivered_at IS NULL
        ORDER BY group_messages.created_at ASC
        LIMIT 100
        "#,
    )
    .bind(&raven_id)
    .bind(&raven_id)
    .bind(&raven_id)
    .fetch_all(&state.db)
    .await?;

    let mut messages = Vec::new();
    for row in rows {
        messages.push(GroupMessageResponse {
            id: row.try_get("id")?,
            client_message_id: row.try_get("client_message_id")?,
            group_id: row.try_get("group_id")?,
            group_name: row.try_get("group_name")?,
            sender_raven_id: row.try_get("sender_raven_id")?,
            encrypted_payload: row.try_get("encrypted_payload")?,
            message_kind: row.try_get("message_kind")?,
            created_at: row.try_get("created_at")?,
            delivered_at: row.try_get("delivered_at")?,
        });
    }
    Ok(Json(messages))
}

async fn mark_group_message_delivered(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(message_id): Path<String>,
) -> ApiResult<Json<GroupMessageResponse>> {
    let token = extract_bearer_token(&headers)?;
    let user = authenticate_token(&state.db, &token).await?;

    let row = sqlx::query(
        r#"
        SELECT group_messages.id, group_messages.client_message_id, group_messages.group_id,
               groups.name AS group_name, group_messages.sender_raven_id,
               group_messages.encrypted_payload, group_messages.message_kind, group_messages.created_at
        FROM group_messages
        INNER JOIN groups ON groups.id = group_messages.group_id
        INNER JOIN group_members ON group_members.group_id = group_messages.group_id
        WHERE group_messages.id = ?
          AND group_members.raven_id = ?
          AND group_members.status = 'accepted'
        LIMIT 1
        "#,
    )
    .bind(&message_id)
    .bind(&user.raven_id)
    .fetch_optional(&state.db)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::NotFound("Group message not found.".to_string()));
    };

    let sender_raven_id: String = row.try_get("sender_raven_id")?;
    let message_kind: String = row.try_get("message_kind")?;
    if sender_raven_id == user.raven_id && message_kind != "system_event" {
        return Err(ApiError::BadRequest("Sender cannot mark own group message as delivered.".to_string()));
    }

    let delivered_at = Utc::now().to_rfc3339();
    sqlx::query(
        r#"
        INSERT INTO group_message_deliveries (message_id, raven_id, delivered_at)
        VALUES (?, ?, ?)
        ON CONFLICT(message_id, raven_id)
        DO UPDATE SET delivered_at = excluded.delivered_at
        "#,
    )
    .bind(&message_id)
    .bind(&user.raven_id)
    .bind(&delivered_at)
    .execute(&state.db)
    .await?;

    Ok(Json(GroupMessageResponse {
        id: row.try_get("id")?,
        client_message_id: row.try_get("client_message_id")?,
        group_id: row.try_get("group_id")?,
        group_name: row.try_get("group_name")?,
        sender_raven_id,
        encrypted_payload: row.try_get("encrypted_payload")?,
        message_kind,
        created_at: row.try_get("created_at")?,
        delivered_at: Some(delivered_at),
    }))
}
