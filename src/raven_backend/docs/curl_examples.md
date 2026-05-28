# Raven Backend curl Examples

Start the backend first in one terminal:

```bash
cd raven_backend
cargo run
```

Keep that terminal open. Use a second terminal for the `curl` commands below.

## 1. Health check

```bash
curl http://127.0.0.1:8080/health
```

Windows Command Prompt:

```bat
curl.exe http://127.0.0.1:8080/health
```

## 2. Register Alice

macOS/Linux/Git Bash:

```bash
curl -X POST http://127.0.0.1:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123","display_name":"Raven User"}'
```

Windows Command Prompt:

```bat
curl.exe -X POST http://127.0.0.1:8080/auth/register -H "Content-Type: application/json" -d "{\"email\":\"alice@example.com\",\"password\":\"password123\",\"display_name\":\"Raven User\"}"
```

Copy Alice's returned `raven_id`. The demo verification code is `123456`.

## 3. Verify Alice

macOS/Linux/Git Bash:

```bash
curl -X POST http://127.0.0.1:8080/auth/verify-email \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","code":"123456"}'
```

Windows Command Prompt:

```bat
curl.exe -X POST http://127.0.0.1:8080/auth/verify-email -H "Content-Type: application/json" -d "{\"email\":\"alice@example.com\",\"code\":\"123456\"}"
```

Copy Alice's returned `session_token`.

## 4. Register Bob

macOS/Linux/Git Bash:

```bash
curl -X POST http://127.0.0.1:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"bob@example.com","password":"password123","display_name":"Bob"}'
```

Windows Command Prompt:

```bat
curl.exe -X POST http://127.0.0.1:8080/auth/register -H "Content-Type: application/json" -d "{\"email\":\"bob@example.com\",\"password\":\"password123\",\"display_name\":\"Bob\"}"
```

Copy Bob's returned `raven_id`.

## 5. Verify Bob

macOS/Linux/Git Bash:

```bash
curl -X POST http://127.0.0.1:8080/auth/verify-email \
  -H "Content-Type: application/json" \
  -d '{"email":"bob@example.com","code":"123456"}'
```

Windows Command Prompt:

```bat
curl.exe -X POST http://127.0.0.1:8080/auth/verify-email -H "Content-Type: application/json" -d "{\"email\":\"bob@example.com\",\"code\":\"123456\"}"
```

Copy Bob's returned `session_token`.

## 6. Search users

```bash
curl "http://127.0.0.1:8080/users/search?q=bob"
```

Windows Command Prompt:

```bat
curl.exe "http://127.0.0.1:8080/users/search?q=bob"
```

## 7. Send a message from Alice to Bob

Use the real values returned by the register/verify requests.

macOS/Linux/Git Bash:

```bash
ALICE_TOKEN="paste_alice_session_token_here"
ALICE_RAVEN_ID="paste_alice_raven_id_here"
BOB_RAVEN_ID="paste_bob_raven_id_here"

curl -X POST http://127.0.0.1:8080/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d "{\"client_message_id\":\"msg-001\",\"sender_raven_id\":\"$ALICE_RAVEN_ID\",\"recipient_raven_id\":\"$BOB_RAVEN_ID\",\"encrypted_payload\":\"demo encrypted payload\"}"
```

Windows Command Prompt example shape:

```bat
curl.exe -X POST http://127.0.0.1:8080/messages -H "Content-Type: application/json" -H "Authorization: Bearer ALICE_TOKEN_HERE" -d "{\"client_message_id\":\"msg-001\",\"sender_raven_id\":\"ALICE_RAVEN_ID_HERE\",\"recipient_raven_id\":\"BOB_RAVEN_ID_HERE\",\"encrypted_payload\":\"demo encrypted payload\"}"
```

Copy the returned backend message `id`. It will be a UUID. Do not use `client_message_id` for delivery confirmation.

## 8. Fetch Bob's pending inbox

macOS/Linux/Git Bash:

```bash
BOB_TOKEN="paste_bob_session_token_here"
BOB_RAVEN_ID="paste_bob_raven_id_here"

curl "http://127.0.0.1:8080/messages/inbox/$BOB_RAVEN_ID" \
  -H "Authorization: Bearer $BOB_TOKEN"
```

Windows Command Prompt example shape:

```bat
curl.exe -H "Authorization: Bearer BOB_TOKEN_HERE" http://127.0.0.1:8080/messages/inbox/BOB_RAVEN_ID_HERE
```

This endpoint returns pending/undelivered messages only.

## 9. Mark message as delivered

Use the backend-generated message `id` returned by `POST /messages` or `GET /messages/inbox/:raven_id`.

macOS/Linux/Git Bash:

```bash
MESSAGE_ID="paste_backend_message_id_here"

curl -X POST "http://127.0.0.1:8080/messages/$MESSAGE_ID/delivered" \
  -H "Authorization: Bearer $BOB_TOKEN"
```

Windows Command Prompt example shape:

```bat
curl.exe -X POST -H "Authorization: Bearer BOB_TOKEN_HERE" http://127.0.0.1:8080/messages/BACKEND_MESSAGE_ID_HERE/delivered
```

After this, fetching Bob's inbox again should return `[]`, because the message is no longer pending.
