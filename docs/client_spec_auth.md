# Client Authentication and Provisioning Specification

This document defines the interface and protocol flow for the client application interacting with the bootstrap authentication server. It serves as a guide for implementing any client, particularly the dual mode bash script client.

## Core Concepts

The bootstrapping process establishes trust between a new client device, an existing administrator device, and the authentication server. The authentication server uses Ed25519 public key cryptography for authentication and `age` for secure payload encryption.

### Dual Mode Client

The client application operates in one of two modes:
1. **Requester Mode**: Used by a new, unprovisioned device to request access and receive secrets.
2. **Approver Mode**: Used by an already provisioned administrator device to authorize pending requests.

---

## The Authentication and Provisioning Flow

The complete flow consists of five sequential phases.

### Phase 1: Administrator Bootstrapping
1. The server starts up. If the `ADMIN_PUBLIC_KEY` environment variable is set, the server automatically registers and approves this public key as an administrator device in the database.
2. The administrator client on the admin machine is configured to use the corresponding private key.

### Phase 2: Client Request Initiation (Requester Mode)
1. The new device runs the client in requester mode:
   ```bash
    b me  (optional: --server <server_url>) [default auth server is https://b.adityagupta.dev/auth]
   ```
2. The client script generates an Ed25519 key pair locally.
3. The client sends a `POST /api/register` request containing its generated public key.
4. The server registers the device in a `pending` state and returns:
   - A short, human readable `user_code` (e.g. 4 to 8 characters).
   - A unique `device_id`.
5. The client script displays the `user_code` to the operator and begins polling the challenge endpoint:
   ```
   GET /api/challenge/poll?device_id=<device_id>
   ```

### Phase 3: Administrator Approval (Approver Mode)
1. The operator reads the `user_code` from the requesting device's terminal.
2. On the administrator device, the operator runs the client in approver mode:
   ```bash
   b trust <user_code> [--server <server_url>]
   ```
3. The administrator client queries the server to retrieve the pending registration details:
   ```
   GET /api/pending/<user_code>
   ```
4. The server returns the pending `device_id` and the requester's `public_key`.
5. The administrator client displays these details. The operator confirms the request.
6. The administrator client signs a payload containing the requester's `device_id` and the approval action using its Ed25519 administrator private key.
7. The administrator client submits the signature and its public key to the server:
   ```
   POST /api/approve
   ```
8. The server verifies the administrator's signature against the registered administrator public keys. If valid, the server transitions the requester device state from `pending` to `approved`.

### Phase 4: Payload Provisioning
1. Once the requester device is approved, the server generates the secret payload (or retrieves it from a secure source).
2. The server encrypts the payload using the requester's public key via `age`.
3. The server stores this encrypted payload as a challenge response.

### Phase 5: Challenge Completion and Retrieval
1. The next poll from the requester client to `GET /api/challenge/poll?device_id=<device_id>` succeeds.
2. The server returns the `age` encrypted payload.
3. The requester client decrypts the payload using its local private key.
4. The secrets are successfully provisioned.

---

## API Endpoints Reference

### 1. Register Device
- **Endpoint**: `POST /api/register`
- **Request Body**:
  ```json
  {
    "public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..."
  }
  ```
- **Response Body (200 OK)**:
  ```json
  {
    "device_id": "uuid-string",
    "user_code": "A3F9K2"
  }
  ```

### 2. Get Pending Device Details
- **Endpoint**: `GET /api/pending/<user_code>`
- **Response Body (200 OK)**:
  ```json
  {
    "device_id": "uuid-string",
    "public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..."
  }
  ```

### 3. Approve Device
- **Endpoint**: `POST /api/approve`
- **Request Body**:
  ```json
  {
    "device_id": "uuid-string",
    "admin_public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...",
    "signature": "hex-encoded-signature-bytes"
  }
  ```
- **Response Body (200 OK)**: Empty or success confirmation.

### 4. Poll Challenge
- **Endpoint**: `GET /api/challenge/poll?device_id=<device_id>`
- **Response Body (200 OK - Pending)**:
  ```json
  {
    "status": "pending"
  }
  ```
- **Response Body (200 OK - Approved & Encrypted)**:
  ```json
  {
    "status": "approved",
    "payload": "-----BEGIN AGE ENCRYPTED FILE-----\n..."
  }
  ```

---

## Bash Client Commands and Usage


### Global Dependencies
- `curl` or `wget` for making HTTP requests.
- `jq` for parsing JSON payloads.
- `ssh-keygen` for Ed25519 key generation and signing.
- `age` and `age-keygen` for decrypting the final payload.

### Command Structure

#### 1. Device Registration Request
Generates local keys, registers with the server, and polls for the encrypted secret payload.
```bash
b me \
  --server <server_url> \
  [--key-dir <directory_to_save_keys>] \
  [--poll-interval <seconds>]
```
- `--server`: Base URL of the bootstrap authentication server.
- `--key-dir`: Directory where the new Ed25519 and age keys will be saved (defaults to `~/.config/bootstrap-client/`).
- `--poll-interval`: Frequency of polling in seconds (defaults to `5`).

#### 2. Request Approval
Retrieves a pending request by its user code, requests user confirmation, signs the approval payload, and sends it to the server.
```bash
b trust <user_code> \
  --server <server_url> \
  --admin-key <path_to_admin_private_key>
```
- `--code`: The short human readable code displayed on the requesting device.
- `--server`: Base URL of the bootstrap authentication server.
- `--admin-key`: Path to the administrator's private key used to sign the approval.
