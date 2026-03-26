set -e

# Source common functions from the same directory as this script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]:-$0}")"
source "${SCRIPT_DIR}/common.sh"

# Load .env values when available (useful for local execution).
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Default SPA parameters (can be overridden via env vars).
SPA_APP_NAME="${THUNDER_SPA_APP_NAME:-Email App}"
SPA_APP_DESCRIPTION="${THUNDER_SPA_APP_DESCRIPTION:-Application for email client to use OAuth2 authentication}"
SPA_CLIENT_ID="${THUNDER_SPA_CLIENT_ID:-EMAIL_APP}"
SPA_ALLOWED_USER_TYPE="${THUNDER_SPA_ALLOWED_USER_TYPE:-Person}"

log_info "Creating single-page application resource..."
echo ""

# ============================================================================
# Helpers
# ============================================================================

extract_first_id() {
    echo "$1" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

create_spa_application() {
    local APP_NAME="$1"
    local APP_DESCRIPTION="$2"
    local CLIENT_ID="$3"
    local ALLOWED_USER_TYPE="$4"
    local RESPONSE HTTP_CODE BODY
    local APP_ID APP_CLIENT_ID

    log_info "Creating ${APP_NAME} application..."

    read -r -d '' APP_PAYLOAD <<JSON || true
{
    "name": "${APP_NAME}",
    "description": "${APP_DESCRIPTION}",
    "is_registration_flow_enabled": false,
    "logo_url": "https://ssl.gstatic.com/docs/common/profile/kiwi_lg.png",
    "assertion": {
        "validity_period": 3600
    },
    "certificate": {
        "type": "NONE"
    },
    "inbound_auth_config": [
        {
            "type": "oauth2",
            "config": {
                "client_id": "${CLIENT_ID}",
                "redirect_uris": [
                    "http://localhost/",
                ],
                "grant_types": [
                    "authorization_code",
                    "refresh_token"
                ],
                "response_types": [
                    "code"
                ],
                "token_endpoint_auth_method": "none",
                "pkce_required": true,
                "public_client": true,
                "token": {
                    "access_token": {
                        "validity_period": 3600,
                        "user_attributes": [
                            "groups",
                            "roles",
                            "ouId",
                            "username"
                        ]
                    },
                    "id_token": {
                        "validity_period": 3600,
                        "user_attributes": [
                            "groups",
                            "roles",
                            "ouId",
                            "username"
                        ]
                    }
                },
                "scopes": [
                    "openid",
                    "profile",
                    "email",
                    "group",
                    "role"
                ],
                "user_info": {
                    "user_attributes": [
                        "groups",
                        "roles",
                        "ouId",
                        "username"
                    ]
                },
                "scope_claims": {
                    "group": [
                        "groups"
                    ],
                    "role": [
                        "roles"
                    ]
                }
            }
        }
    ],
    "allowed_user_types": [
        "${ALLOWED_USER_TYPE}"
    ]
}
JSON

    RESPONSE=$(thunder_api_call POST "/applications" "${APP_PAYLOAD}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "202" ]]; then
        log_success "${APP_NAME} application created successfully"
        APP_ID=$(extract_first_id "$BODY")
        APP_CLIENT_ID=$(echo "$BODY" | grep -o '"client_id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [[ -n "$APP_ID" ]]; then
            log_info "${APP_NAME} app ID: ${APP_ID}"
        fi
        if [[ -n "$APP_CLIENT_ID" ]]; then
            log_info "${APP_NAME} client ID: ${APP_CLIENT_ID}"
        fi
    elif [[ "$HTTP_CODE" == "409" ]] || ([[ "$HTTP_CODE" == "400" ]] && [[ "$BODY" =~ (Application\ already\ exists|APP-1022) ]]); then
        log_warning "${APP_NAME} application already exists, skipping"
    else
        log_error "Failed to create ${APP_NAME} application (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        exit 1
    fi
}

# ============================================================================
# Create Single SPA Application
# ============================================================================

create_spa_application "$SPA_APP_NAME" "$SPA_APP_DESCRIPTION" "$SPA_CLIENT_ID" "$SPA_ALLOWED_USER_TYPE"

echo ""
log_success "Single-page application setup completed successfully!"
log_info "App name: ${SPA_APP_NAME}"
log_info "App client ID: ${SPA_CLIENT_ID}"
log_info "Allowed user type: ${SPA_ALLOWED_USER_TYPE}"
log_info "Redirect URIs: http://localhost/"
echo ""