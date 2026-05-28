# Raven Backend Contract v1 (Draft)

This document is a placeholder contract prepared before implementing the Rust backend. It reflects the current Sprint 8/9 product flow and keeps the Flutter app organized for the next integration phase.

## Principles

- The backend should behave as a relay and account service.
- Message content should be handled as `encryptedPayload`, even while the current Flutter prototype still uses local/demo payloads.
- Account authentication and local PIN/vault access remain separate concepts.
- Local PIN recovery is optional and depends on the user enabling email-based recovery before losing access.

## Auth endpoints

```http
POST /auth/register
POST /auth/login
POST /auth/verify-email
POST /auth/forgot-password
POST /auth/reset-password
```

## User endpoints

```http
GET /users/search?q=
GET /users/:ravenId
PATCH /users/me/profile
PATCH /users/me/email
```

## Message endpoints

```http
POST /messages
GET /messages/inbox/:ravenId
POST /messages/:id/delivered
```

## Group endpoints

```http
POST /groups
GET /groups/search?q=
GET /groups/:id
PATCH /groups/:id
POST /groups/:id/invite
POST /groups/:id/members
DELETE /groups/:id/members/:memberId
```

## Initial database tables

- users
- devices
- groups
- group_members
- group_invites
- messages
- verification_codes
- password_reset_codes

## Flutter integration target

The Flutter app should later connect through repository/service classes rather than calling backend APIs directly from screens.
