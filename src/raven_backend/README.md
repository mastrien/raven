# Raven Backend Foundation

This is the first Rust backend foundation for Raven.

It is intentionally small: it supports account registration/login, email verification with a demo code, password reset with a demo code, user search, and a direct-message relay.

The backend is designed to treat message content as `encrypted_payload`. Even while the Flutter app still sends demo/plain payloads during integration, the backend contract is already shaped for end-to-end encrypted messages.

## Stack

- Rust
- Axum
- Tokio
- SQLite
- SQLx
- Argon2 password hashing

## Run locally

macOS/Linux/Git Bash:

```bash
cd raven_backend
cp .env.example .env
cargo run
```

Windows Command Prompt:

```bat
cd raven_backend
copy .env.example .env
cargo run
```

Windows PowerShell:

```powershell
cd raven_backend
Copy-Item .env.example .env
cargo run
```

The server starts at:

```text
http://127.0.0.1:8080
```

Health check:

```bash
curl http://127.0.0.1:8080/health
```

Expected response:

```json
{"ok":true,"service":"raven_backend"}
```

## Demo verification code

For local development, verification and reset flows use:

```text
123456
```

This is controlled by:

```text
RAVEN_DEMO_CODES=true
```

Real email delivery should be added later.

## Auth model

Account authentication and local vault access are separate.

- Email + account password: remote account session.
- Main/Cover/Emergency PINs: local vault/environment access in the Flutter app.

This backend does **not** know the user's local PINs.

## Current endpoints

```http
POST /auth/register
POST /auth/verify-email
POST /auth/login
POST /auth/forgot-password
POST /auth/reset-password
GET  /users/search?q=
GET  /users/:raven_id
POST /messages
GET  /messages/inbox/:raven_id
POST /messages/:id/delivered
```

Session-protected endpoints accept either:

```http
Authorization: Bearer <session_token>
```

or:

```http
x-raven-session: <session_token>
```

## Sprint 10 scope

Included now:

- Account creation.
- Demo email verification.
- Login with Argon2 password hashing.
- Demo password recovery.
- Raven ID generation.
- User search by Raven ID or display name.
- Direct message relay using `encrypted_payload`.
- Pending inbox fetch.
- Mark message as delivered.

## Message delivery semantics

`GET /messages/inbox/:raven_id` returns only pending, undelivered messages for the authenticated recipient. After a message is marked as delivered, it no longer appears in this inbox response.

`POST /messages/:id/delivered` expects the backend-generated message `id`, not the optional `client_message_id` supplied by the Flutter app. For example, use the UUID returned in the `id` field of `POST /messages`, not a value like `msg-001`.


Not included yet:

- Flutter integration.
- Real email sending.
- Real end-to-end encryption.
- Groups and group invites.
- Push notifications.
- Rate limiting.
- Production deployment hardening.

## Suggested next sprint

Sprint 10B should connect Flutter to:

- register/login/verify-email;
- user search;
- send message;
- inbox polling/fetch;
- mark delivered.

Groups should come after direct messages are stable.

## Sprint 11 additions

### Delivery status sync

After a recipient syncs their inbox and marks a message delivered, the sender can fetch outgoing status:

```bat
curl.exe -H "Authorization: Bearer ALICE_TOKEN" http://127.0.0.1:8080/messages/outbox/ALICE_RAVEN_ID/status
```

Flutter uses this in **Sync backend** to update outgoing direct messages from `sent` to `delivered`.

### Groups

Sprint 11 adds backend-backed groups:

- `POST /groups` creates a group.
- `GET /groups/search?q=` searches groups visible to the authenticated user.
- `GET /groups/mine/:raven_id` lists the authenticated user's accepted groups.
- `POST /groups/:group_id/members` adds a member or creates an invite depending on the target user's group privacy policy.
- `GET /groups/invites/:raven_id` returns pending group invites.
- `POST /groups/:group_id/invites/respond` accepts or declines an invite.
- `POST /groups/:group_id/messages` sends a group message.
- `GET /groups/inbox/:raven_id` fetches pending group messages.
- `POST /groups/messages/:message_id/delivered` marks a group message delivered.

For MVP usability, new local users default to `group_add_policy = everyone`; the data model still supports invitation-based group joins.
