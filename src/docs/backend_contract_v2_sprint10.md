# Raven Backend Contract v2 — Sprint 10 Implemented Foundation

This contract reflects the first Rust backend implementation added under `raven_backend/`.

## Principles

- The backend is an account service and encrypted-message relay.
- The backend stores message content only as `encrypted_payload`.
- Account password and local PIN/vault access are separate concepts.
- The backend does not know Main/Cover/Emergency PINs.
- Verification and password reset use demo code `123456` until email delivery is added.

## Base URL

```text
http://127.0.0.1:8080
```

## Authentication

Protected endpoints accept:

```http
Authorization: Bearer <session_token>
```

or:

```http
x-raven-session: <session_token>
```

## Auth endpoints

### Register

```http
POST /auth/register
```

Request:

```json
{
  "email": "alice@example.com",
  "password": "password123",
  "display_name": "Raven User"
}
```

`display_name` is optional. If omitted, backend uses `Raven User`.

Response:

```json
{
  "user": {
    "raven_id": "rvn_user_A1B2C3",
    "display_name": "Raven User",
    "email_verified": false
  },
  "session_token": null,
  "demo_code": "123456"
}
```

### Verify email

```http
POST /auth/verify-email
```

Request:

```json
{
  "email": "alice@example.com",
  "code": "123456"
}
```

Response includes a session token.

### Login

```http
POST /auth/login
```

Request:

```json
{
  "email": "alice@example.com",
  "password": "password123"
}
```

Response includes a session token.

### Forgot password

```http
POST /auth/forgot-password
```

Request:

```json
{
  "email": "alice@example.com"
}
```

Privacy-safe response: does not reveal if the account exists.

### Reset password

```http
POST /auth/reset-password
```

Request:

```json
{
  "email": "alice@example.com",
  "code": "123456",
  "new_password": "newpassword123"
}
```

## User endpoints

### Search users

```http
GET /users/search?q=<query>
```

Searches Raven ID and display name.

### Get user

```http
GET /users/:raven_id
```

## Message endpoints

### Send message

```http
POST /messages/
Authorization: Bearer <session_token>
```

Request:

```json
{
  "client_message_id": "optional-client-id",
  "sender_raven_id": "rvn_user_A1B2C3",
  "recipient_raven_id": "rvn_user_D4E5F6",
  "encrypted_payload": "base64-or-json-encrypted-payload"
}
```

### Fetch pending inbox

```http
GET /messages/inbox/:raven_id
Authorization: Bearer <session_token>
```

Returns only pending, undelivered messages for that Raven ID. Once `delivered_at` is set, the message no longer appears in this endpoint.

### Mark delivered

```http
POST /messages/:id/delivered
Authorization: Bearer <session_token>
```

`:id` is the backend-generated message `id` returned by `POST /messages` or `GET /messages/inbox/:raven_id`. It is not the optional `client_message_id`.

Only the recipient can mark a message as delivered.

## Sprint 10 database tables

- `users`
- `verification_codes`
- `sessions`
- `messages`

## Deferred to later sprints

- Flutter integration.
- Real email sending.
- Groups and group invitations.
- Online status/read receipts backend behavior.
- Real E2E encryption protocol.
- Rate limiting and production security hardening.
