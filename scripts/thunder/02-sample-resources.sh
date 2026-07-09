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
SPA_OU_HANDLE="${THUNDER_SPA_OU_HANDLE:-default}"

log_info "Creating single-page application resource..."
echo ""

# ============================================================================
# Helpers
# ============================================================================

extract_json_value() {
    local JSON_STRING="$1"
    local KEY="$2"

    echo "$JSON_STRING" | grep -o "\"${KEY}\":\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_ou_id_by_handle() {
    local OU_HANDLE="$1"
    local RESPONSE HTTP_CODE BODY OU_ID

    RESPONSE=$(thunder_api_call GET "/organization-units/tree/${OU_HANDLE}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" != "200" ]]; then
        log_error "Failed to resolve OU '${OU_HANDLE}' (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        return 1
    fi

    OU_ID=$(extract_json_value "$BODY" "id")
    if [[ -z "$OU_ID" ]]; then
        log_error "Could not extract OU ID for handle '${OU_HANDLE}'"
        return 1
    fi

    echo "$OU_ID"
}

get_first_flow_id() {
    local FLOW_TYPE="$1"
    local RESPONSE HTTP_CODE BODY FLOW_ID

    RESPONSE=$(thunder_api_call GET "/flows?flowType=${FLOW_TYPE}&limit=1")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" != "200" ]]; then
        log_error "Failed to fetch ${FLOW_TYPE} flows (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        return 1
    fi

    FLOW_ID=$(extract_json_value "$BODY" "id")
    if [[ -z "$FLOW_ID" ]]; then
        log_error "No ${FLOW_TYPE} flow found. Run default resource bootstrap first."
        return 1
    fi

    echo "$FLOW_ID"
}

create_spa_application() {
    local APP_NAME="$1"
    local APP_DESCRIPTION="$2"
    local CLIENT_ID="$3"
    local ALLOWED_USER_TYPE="$4"
    local RESPONSE HTTP_CODE BODY
    local APP_ID APP_CLIENT_ID
    local APP_OU_ID AUTH_FLOW_ID REG_FLOW_ID

    log_info "Creating ${APP_NAME} application..."

    APP_OU_ID=$(get_ou_id_by_handle "$SPA_OU_HANDLE") || exit 1
    AUTH_FLOW_ID=$(get_first_flow_id "AUTHENTICATION") || exit 1
    REG_FLOW_ID=$(get_first_flow_id "REGISTRATION") || exit 1

    read -r -d '' APP_PAYLOAD <<JSON || true
{
    "name": "${APP_NAME}",
    "description": "${APP_DESCRIPTION}",
    "ouId": "${APP_OU_ID}",
    "url": "http://localhost/",
    "logoUrl": "https://ssl.gstatic.com/docs/common/profile/kiwi_lg.png",
    "authFlowId": "${AUTH_FLOW_ID}",
    "registrationFlowId": "${REG_FLOW_ID}",
    "isRegistrationFlowEnabled": false,
    "allowedUserTypes": [
        "${ALLOWED_USER_TYPE}"
    ],
    "userAttributes": [
        "groups",
        "roles",
        "ouId",
        "username"
    ],
    "inboundAuthConfig": [
        {
            "type": "oauth2",
            "config": {
                "clientId": "${CLIENT_ID}",
                "redirectUris": [
                    "http://localhost/"
                ],
                "grantTypes": [
                    "authorization_code",
                    "refresh_token"
                ],
                "responseTypes": [
                    "code"
                ],
                "tokenEndpointAuthMethod": "none",
                "pkceRequired": true,
                "publicClient": true,
                "token": {
                    "accessToken": {
                        "validityPeriod": 3600,
                        "userAttributes": [
                            "groups",
                            "roles",
                            "ouId",
                            "username"
                        ]
                    },
                    "idToken": {
                        "validityPeriod": 3600,
                        "userAttributes": [
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
                "scopeClaims": {
                    "profile": [
                        "name",
                        "given_name",
                        "family_name",
                        "picture"
                    ],
                    "email": [
                        "email",
                        "email_verified"
                    ],
                    "group": [
                        "groups"
                    ],
                    "ou": [
                        "ouId"
                    ]
                }
            }
        }
    ]
}
JSON

    RESPONSE=$(thunder_api_call POST "/applications" "${APP_PAYLOAD}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "202" ]]; then
        log_success "${APP_NAME} application created successfully"
        APP_ID=$(extract_json_value "$BODY" "id")
        APP_CLIENT_ID=$(extract_json_value "$BODY" "clientId")
        if [[ -z "$APP_CLIENT_ID" ]]; then
            APP_CLIENT_ID=$(extract_json_value "$BODY" "client_id")
        fi
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