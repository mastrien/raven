use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize)]
pub struct UserPublic {
    pub raven_id: String,
    pub display_name: String,
    pub email_verified: bool,
}

#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub raven_id: String,
}

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub display_name: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct VerifyEmailRequest {
    pub email: String,
    pub code: String,
}

#[derive(Debug, Deserialize)]
pub struct ForgotPasswordRequest {
    pub email: String,
}

#[derive(Debug, Deserialize)]
pub struct ResetPasswordRequest {
    pub email: String,
    pub code: String,
    pub new_password: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub user: UserPublic,
    pub session_token: Option<String>,
    pub demo_code: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct BasicResponse {
    pub ok: bool,
    pub message: String,
    pub demo_code: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct SearchQuery {
    pub q: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateProfileRequest {
    pub display_name: String,
}

#[derive(Debug, Deserialize)]
pub struct SendMessageRequest {
    pub client_message_id: Option<String>,
    pub sender_raven_id: String,
    pub recipient_raven_id: String,
    pub encrypted_payload: String,
}

#[derive(Debug, Serialize)]
pub struct MessageResponse {
    pub id: String,
    pub client_message_id: Option<String>,
    pub sender_raven_id: String,
    pub recipient_raven_id: String,
    pub encrypted_payload: String,
    pub created_at: String,
    pub delivered_at: Option<String>,
}


#[derive(Debug, Serialize)]
pub struct MessageStatusResponse {
    pub id: String,
    pub client_message_id: Option<String>,
    pub recipient_raven_id: String,
    pub delivered_at: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub ok: bool,
    pub service: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateGroupRequest {
    pub client_group_id: Option<String>,
    pub name: String,
    pub owner_raven_id: String,
    #[serde(default)]
    pub member_raven_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct AddGroupMemberRequest {
    pub member_raven_id: String,
}

#[derive(Debug, Deserialize)]
pub struct RenameGroupRequest {
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct SendGroupMessageRequest {
    pub client_message_id: Option<String>,
    pub sender_raven_id: String,
    pub encrypted_payload: String,
}

#[derive(Debug, Deserialize)]
pub struct RespondGroupInviteRequest {
    pub response: String,
}

#[derive(Debug, Serialize)]
pub struct GroupResponse {
    pub id: String,
    pub client_group_id: Option<String>,
    pub name: String,
    pub owner_raven_id: String,
    pub member_raven_ids: Vec<String>,
    pub invited_raven_ids: Vec<String>,
    pub status: String,
    pub my_status: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
pub struct GroupInviteResponse {
    pub group_id: String,
    pub group_name: String,
    pub inviter_raven_id: String,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
pub struct GroupMessageResponse {
    pub id: String,
    pub client_message_id: Option<String>,
    pub group_id: String,
    pub group_name: String,
    pub sender_raven_id: String,
    pub encrypted_payload: String,
    pub message_kind: String,
    pub created_at: String,
    pub delivered_at: Option<String>,
}
