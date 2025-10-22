-- Requires LuaSocket and LuaSec
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson") -- For JSON parsing. Install if needed.

-- Helper function to POST JSON to API
local function api_authenticate(user, password, req)
    req:log_debug("Starting API authentication for user: " .. user)

    local request_body = json.encode({
        email = user,
        password = password,
        skip_assertion = true
    })
    local response_body = {}

    local params = {
        url = "https://thunder-server:8090/auth/credentials/authenticate",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#request_body)
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body),

        protocol = "tlsv1_2", -- enforce TLS 1.2+
        options = "all",

        cafile = "/etc/ssl/certs/ca-certificates.crt", -- system CA store (Debian/Ubuntu)
        verify = "peer", -- verify server certificate
        verifyext = {"lsec_continue"}
    }

    local res, code, headers, status = https.request(params)

    req:log_debug("HTTPS request finished. HTTP code: " .. tostring(code))

    if not res then
        req:log_error("API request failed: " .. tostring(status))
        return nil, "API request failed"
    end

    if code ~= 200 then
        req:log_error("API returned non-200 status: " .. tostring(code))
        return nil, "API error: " .. tostring(code)
    end

    local resp_str = table.concat(response_body)
    req:log_debug("Raw API response: " .. resp_str)

    local resp_json, pos, err = json.decode(resp_str)
    if not resp_json then
        req:log_error("JSON decode error: " .. err)
        return nil, "JSON decode error: " .. err
    end

    if resp_json.id then
        req:log_info("User " .. user .. " authenticated successfully. ID=" .. resp_json.id)
        return true
    else
        req:log_warning("API authentication failed for user: " .. user)
        return false
    end
end

-- Passdb function
function auth_passdb_lookup(req)

    local mail_domain = __MAIL_DOMAIN__

    req:log_debug("auth_passdb_lookup called for user: " .. (req.username or "nil"))

    local user = req.username
    if not user:find("@") then
        user = user .. "@" .. mail_domain
    end

    local success, err = api_authenticate(user, req.password, req)

    if success then
        req:log_debug("auth_passdb_lookup: PASSDB_RESULT_OK")
        return dovecot.auth.PASSDB_RESULT_OK, "password=" .. req.password
    else
        req:log_debug("auth_passdb_lookup: PASSDB_RESULT_USER_UNKNOWN")
        return dovecot.auth.PASSDB_RESULT_USER_UNKNOWN, err or "authentication failed"
    end
end

-- Userdb lookup
function auth_userdb_lookup(req)
    req:log_debug("auth_userdb_lookup called for user: " .. (req.username or "nil"))

    if not req.username then
        return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "no such user"
    end

    -- Build SCIM filter request (search by username, not email)
    local url = "https://thunder-server:8090/users?filter=username%20eq%20%22" .. req.username .. "%22"
    local response_body = {}

    local params = {
        url = url,
        method = "GET",
        sink = ltn12.sink.table(response_body),

        protocol = "tlsv1_2", -- enforce TLS 1.2+
        options = "all",
        cafile = "/etc/ssl/certs/ca-certificates.crt", -- system CA store
        verify = "peer", -- verify server certificate
        verifyext = {"lsec_continue"}
    }

    local ok, code, headers, status = https.request(params)

    if not ok or code ~= 200 then
        req:log_error("User lookup API error: " .. tostring(status))
        return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "API error"
    end

    local body = table.concat(response_body)
    req:log_debug("User lookup raw API response: " .. body)

    local data, pos, err = json.decode(body, 1, nil)
    if err then
        req:log_error("User lookup JSON decode error: " .. err)
        return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "invalid JSON"
    end

    -- Compare username field
    if data and data.users and #data.users > 0 then
        local user = data.users[1]
        if user.attributes and user.attributes.username == req.username then
            return dovecot.auth.USERDB_RESULT_OK, "uid=5000 gid=5000 home=/var/mail/vmail/" .. req.username ..
                " mail=maildir:/var/mail/vmail/" .. req.username
        end
    end

    return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "no such user"
end

function auth_userdb_iterate()
    return {} -- empty
end

function script_init()
    return 0
end
function script_deinit()
end
