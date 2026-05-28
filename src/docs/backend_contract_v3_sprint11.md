# Raven backend contract v3 - Sprint 11

## Direct messages

### GET /messages/outbox/:raven_id/status
Returns delivery status for messages sent by the authenticated user.

Response item:
```json
{
  "id": "server-message-id",
  "client_message_id": "local-message-id",
  "recipient_raven_id": "rvn_bob_ABC123",
  "delivered_at": "2026-05-27T19:26:41Z"
}
```

## Groups

### POST /groups
Creates a group.

Request:
```json
{
  "client_group_id": "group_local_123",
  "name": "Project group",
  "owner_raven_id": "rvn_alice_ABC123",
  "member_raven_ids": ["rvn_bob_DEF456"]
}
```

### GET /groups/search?q=project
Searches accepted groups visible to the authenticated user.

### GET /groups/mine/:raven_id
Returns groups where the authenticated user is an accepted member.

### GET /groups/by-id/:group_id
Returns group details if the authenticated user belongs to the group.

### POST /groups/:group_id/members
Adds a member or creates an invite depending on the target user's group privacy setting.

Request:
```json
{"member_raven_id":"rvn_bob_DEF456"}
```

### GET /groups/invites/:raven_id
Returns pending group invites for the authenticated user.

### POST /groups/:group_id/invites/respond
Accepts or declines a group invite.

Request:
```json
{"response":"accept"}
```

## Group messages

### POST /groups/:group_id/messages
Sends a group message as encrypted_payload.

Request:
```json
{
  "client_message_id": "message_local_123",
  "sender_raven_id": "rvn_alice_ABC123",
  "encrypted_payload": "demo payload"
}
```

### GET /groups/inbox/:raven_id
Returns pending group messages for the authenticated user.

### POST /groups/messages/:message_id/delivered
Marks one group message as delivered for the authenticated user.

## Sprint 11C additions

### Profile sync

`PATCH /users/me/profile`

Request:

```json
{
  "display_name": "Bob"
}
```

Response: `UserPublic`.

Flutter uses this when editing the current public profile. Other devices refresh remote display names during backend sync. Local aliases must not be overwritten.

### Group state

Groups now expose:

```json
{
  "status": "active | closed",
  "my_status": "accepted | invited | left | removed | declined"
}
```

The active member count is derived from `member_raven_ids`, which contains only accepted active members.

### Group lifecycle endpoints

`PATCH /groups/:group_id/rename`

Request:

```json
{
  "name": "New group name"
}
```

`POST /groups/:group_id/leave`

Marks the current user as left. The group remains visible as inactive on the user's device.

`POST /groups/:group_id/close`

Owner/admin action. Closes the group and marks all accepted members as left.

### System events

Group messages now include:

```json
{
  "message_kind": "user_message | system_event"
}
```

System events should render as neutral centered timeline messages, not as normal user bubbles.
