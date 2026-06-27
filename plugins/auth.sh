#!/usr/bin/env bash
#
# Authentication & Provisioning Plugin for Bootstrap CLI
# Handles requester (b me) and approver (b trust) flows.
#

set -euo pipefail

# Ensure dependencies are met
pkg_install "arch:openssh|debian:openssh-client|fedora:openssh-clients" "curl" "jq" "age"


# Ensure public key exists next to private key for ssh-keygen -Y sign
ensure_pubkey_exists() {
    local priv_key="$1"
    local pub_key="${priv_key}.pub"
    if [ ! -f "$pub_key" ]; then
        ssh-keygen -y -f "$priv_key" > "$pub_key"
    fi
}

COMMAND="${1:-}"
if [ -z "$COMMAND" ]; then
    echo "Usage: b auth <me|trust> [args...]" >&2
    exit 1
fi
shift

# Defaults
SERVER_URL="https://b.adityagupta.dev/auth"
KEY_DIR="$HOME/.config/bootstrap-client"
POLL_INTERVAL=5
ADMIN_KEY="$HOME/.ssh/id_ed25519"
USER_CODE=""

if [ "$COMMAND" = "trust" ]; then
    if [ $# -lt 1 ]; then
        log_error "user_code is required for trust."
        echo "Usage: b trust <user_code> [--server <server_url>] [--admin-key <path>]" >&2
        exit 1
    fi
    USER_CODE="$1"
    shift
fi

# Parse remaining arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --server)
            SERVER_URL="$2"
            shift 2
            ;;
        --key-dir)
            KEY_DIR="$2"
            shift 2
            ;;
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        --admin-key)
            ADMIN_KEY="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ "$COMMAND" = "me" ]; then
    mkdir -p "$KEY_DIR"
    local_key="$KEY_DIR/id_ed25519"
    
    if [ ! -f "$local_key" ]; then
        log_info "Generating local Ed25519 key pair under $KEY_DIR..."
        ssh-keygen -t ed25519 -N "" -f "$local_key" >/dev/null
    fi
    
    ensure_pubkey_exists "$local_key"
    pub_key=$(cat "${local_key}.pub")
    hostname=$(hostname 2>/dev/null || uname -n)
    os=$(uname -s 2>/dev/null || echo "linux")
    
    # Safely construct JSON payload
    json_payload=$(jq -n \
      --arg hn "$hostname" \
      --arg os "$os" \
      --arg pk "$pub_key" \
      '{hostname: $hn, os: $os, public_key: $pk}')
      
    log_info "Registering device with $SERVER_URL..."
    
    register_response=$(curl -fsSL -X POST \
      -H "Content-Type: application/json" \
      -d "$json_payload" \
      "$SERVER_URL/api/register")
      
    user_code=$(echo "$register_response" | jq -r '.user_code // empty')
    challenge_nonce=$(echo "$register_response" | jq -r '.challenge_nonce // empty')
    
    if [ -z "$user_code" ] || [ -z "$challenge_nonce" ]; then
        log_error "Failed to retrieve registration codes from server response."
        exit 1
    fi
    
    echo "--------------------------------------------------------"
    log_success "Device registration initiated successfully!"
    echo "Please authorize this device on your administrator machine using:"
    echo "  b trust $user_code --server $SERVER_URL"
    echo "--------------------------------------------------------"
    echo "Verification Code: $user_code"
    echo "--------------------------------------------------------"
    log_info "Waiting for administrator approval (polling every ${POLL_INTERVAL}s)..."
    
    # Prepare challenge poll file signing
    temp_nonce_file=$(mktemp)
    temp_sig_file="${temp_nonce_file}.sig"
    echo -n "$challenge_nonce" > "$temp_nonce_file"
    
    # Ensure cleanup of temp files
    cleanup() {
        rm -f "$temp_nonce_file" "$temp_sig_file"
    }
    trap cleanup EXIT INT TERM
    
    while true; do
        rm -f "$temp_sig_file"
        
        # Sign challenge nonce
        if ! ssh-keygen -Y sign -f "$local_key" -n "bootstrap" "$temp_nonce_file" >/dev/null 2>&1; then
            log_error "Cryptographic signing of challenge nonce failed."
            exit 1
        fi
        
        # Get raw base64 from armored signature file
        signature_b64=$(grep -v '^-' "$temp_sig_file" | tr -d '\n')
        
        poll_payload=$(jq -n \
          --arg uc "$user_code" \
          --arg sig "$signature_b64" \
          '{user_code: $uc, signature: $sig}')
          
        poll_out=$(mktemp)
        http_code=$(curl -s -o "$poll_out" -w "%{http_code}" -X POST \
          -H "Content-Type: application/json" \
          -d "$poll_payload" \
          "$SERVER_URL/api/challenge/poll")
          
        poll_body=$(cat "$poll_out")
        rm -f "$poll_out"
        
        if [ "$http_code" = "200" ]; then
            enc_secrets=$(echo "$poll_body" | jq -r '.encrypted_secrets // empty')
            if [ -n "$enc_secrets" ] && [ "$enc_secrets" != "null" ]; then
                log_success "Device approved by administrator! Decrypting secrets payload..."
                
                decrypted_file="$KEY_DIR/secrets.decrypted"
                if echo "$enc_secrets" | base64 -d | age --decrypt -i "$local_key" > "$decrypted_file" 2>/dev/null; then
                    log_success "Secrets successfully provisioned and written to: $decrypted_file"
                    cat "$decrypted_file"
                    break
                else
                    log_error "Decryption using age failed. Please ensure the private key has not been altered."
                    exit 1
                fi
            fi
        fi
        
        sleep "$POLL_INTERVAL"
    done

elif [ "$COMMAND" = "trust" ]; then
    if [ ! -f "$ADMIN_KEY" ]; then
        log_error "Admin private key not found at: $ADMIN_KEY"
        exit 1
    fi
    
    ensure_pubkey_exists "$ADMIN_KEY"
    
    log_info "Fetching pending device details for user code: $USER_CODE"
    pending_response=$(curl -fsSL "$SERVER_URL/api/pending/$USER_CODE")
    
    requester_pub_key=$(echo "$pending_response" | jq -r '.public_key // empty')
    if [ -z "$requester_pub_key" ]; then
        log_error "No pending registration found for code '$USER_CODE'."
        exit 1
    fi
    
    echo "--------------------------------------------------------"
    echo "Pending Device Public Key:"
    echo "$requester_pub_key"
    echo "--------------------------------------------------------"
    
    # Prompt for confirmation (read from tty to support pipeline scenarios)
    read -r -p "Do you trust and approve this device? [y/N]: " confirm_choice </dev/tty || confirm_choice="N"
    if [[ ! "$confirm_choice" =~ ^[Yy]$ ]]; then
        log_warn "Approval aborted."
        exit 0
    fi
    
    # Generate signature of the requester's public key
    temp_pubkey_file=$(mktemp)
    temp_pubkey_sig_file="${temp_pubkey_file}.sig"
    echo -n "$requester_pub_key" > "$temp_pubkey_file"
    
    # Cleanup trap
    cleanup_trust() {
        rm -f "$temp_pubkey_file" "$temp_pubkey_sig_file"
    }
    trap cleanup_trust EXIT INT TERM
    
    if ! ssh-keygen -Y sign -f "$ADMIN_KEY" -n "bootstrap" "$temp_pubkey_file" >/dev/null 2>&1; then
        log_error "Cryptographic signing using administrator key failed."
        exit 1
    fi
    
    signature_b64=$(grep -v '^-' "$temp_pubkey_sig_file" | tr -d '\n')
    
    # Get fingerprint
    admin_pubkey_str=$(ssh-keygen -y -f "$ADMIN_KEY")
    temp_admin_pub=$(mktemp)
    echo "$admin_pubkey_str" > "$temp_admin_pub"
    approver_fingerprint=$(ssh-keygen -lf "$temp_admin_pub" | awk '{print $2}')
    rm -f "$temp_admin_pub"
    
    # Prepare payload
    approve_payload=$(jq -n \
      --arg uc "$USER_CODE" \
      --arg fp "$approver_fingerprint" \
      --arg sig "$signature_b64" \
      '{user_code: $uc, approver_public_key_fingerprint: $fp, signature: $sig}')
      
    log_info "Submitting cryptographic approval to server..."
    curl -fsSL -X POST \
      -H "Content-Type: application/json" \
      -d "$approve_payload" \
      "$SERVER_URL/api/approve"
      
    log_success "Device with code $USER_CODE has been approved."
fi
