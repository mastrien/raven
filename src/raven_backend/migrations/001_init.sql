PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    raven_id TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    email_hash TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    email_verified_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    allow_display_name_search INTEGER NOT NULL DEFAULT 1,
    allow_online_status INTEGER NOT NULL DEFAULT 1,
    allow_read_receipts INTEGER NOT NULL DEFAULT 1,
    group_add_policy TEXT NOT NULL DEFAULT 'everyone'
);

CREATE INDEX IF NOT EXISTS idx_users_raven_id ON users(raven_id);
CREATE INDEX IF NOT EXISTS idx_users_display_name ON users(display_name);
CREATE INDEX IF NOT EXISTS idx_users_email_hash ON users(email_hash);

CREATE TABLE IF NOT EXISTS verification_codes (
    id TEXT PRIMARY KEY,
    email_hash TEXT NOT NULL,
    purpose TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    consumed_at TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_verification_codes_lookup
ON verification_codes(email_hash, purpose, consumed_at, expires_at);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);

CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    client_message_id TEXT,
    sender_raven_id TEXT NOT NULL,
    recipient_raven_id TEXT NOT NULL,
    encrypted_payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    delivered_at TEXT,
    read_at TEXT,
    FOREIGN KEY(sender_raven_id) REFERENCES users(raven_id) ON DELETE CASCADE,
    FOREIGN KEY(recipient_raven_id) REFERENCES users(raven_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_messages_recipient_pending
ON messages(recipient_raven_id, delivered_at, created_at);

CREATE INDEX IF NOT EXISTS idx_messages_sender_created
ON messages(sender_raven_id, created_at);

CREATE TABLE IF NOT EXISTS groups (
    id TEXT PRIMARY KEY,
    client_group_id TEXT,
    name TEXT NOT NULL,
    owner_raven_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(owner_raven_id) REFERENCES users(raven_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_groups_name ON groups(name);
CREATE INDEX IF NOT EXISTS idx_groups_owner ON groups(owner_raven_id);

CREATE TABLE IF NOT EXISTS group_members (
    group_id TEXT NOT NULL,
    raven_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    status TEXT NOT NULL DEFAULT 'accepted',
    added_at TEXT NOT NULL,
    responded_at TEXT,
    PRIMARY KEY(group_id, raven_id),
    FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY(raven_id) REFERENCES users(raven_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(raven_id, status);
CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id, status);

CREATE TABLE IF NOT EXISTS group_messages (
    id TEXT PRIMARY KEY,
    client_message_id TEXT,
    group_id TEXT NOT NULL,
    sender_raven_id TEXT NOT NULL,
    encrypted_payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY(sender_raven_id) REFERENCES users(raven_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_group_messages_group_created ON group_messages(group_id, created_at);

CREATE TABLE IF NOT EXISTS group_message_deliveries (
    message_id TEXT NOT NULL,
    raven_id TEXT NOT NULL,
    delivered_at TEXT NOT NULL,
    PRIMARY KEY(message_id, raven_id),
    FOREIGN KEY(message_id) REFERENCES group_messages(id) ON DELETE CASCADE,
    FOREIGN KEY(raven_id) REFERENCES users(raven_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_group_message_deliveries_user ON group_message_deliveries(raven_id);

UPDATE users SET group_add_policy = 'everyone' WHERE group_add_policy = 'invite';

ALTER TABLE users ADD COLUMN avatar_url TEXT NOT NULL DEFAULT '';
ALTER TABLE groups ADD COLUMN status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE groups ADD COLUMN closed_at TEXT;
ALTER TABLE group_messages ADD COLUMN message_kind TEXT NOT NULL DEFAULT 'user_message';
