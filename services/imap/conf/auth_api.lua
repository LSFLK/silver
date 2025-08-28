-- Requires LuaSocket and LuaSec
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")  -- For JSON parsing. Install if needed.

-- Helper function to POST JSON to API
local function api_authenticate(user, password, req)
    req:log_debug("Starting API authentication for user: " .. user)

    local request_body = json.encode({ email = user, password = password })
    local response_body = {}

    local res, code, headers, status = https.request{
        url = "https://thunder-server:8090/users/authenticate",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#request_body)
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    }

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

    -- Check if the response contains an ID
    if resp_json.id then
        req:log_info("User " .. user .. " authenticated successfully. ID=" .. resp_json.id ..
                    ", Type=" .. tostring(resp_json.type) ..
                    ", OrgUnit=" .. tostring(resp_json.organizationUnit))
        return true
    else
        req:log_warning("API authentication failed for user: " .. user)
        return false
    end
end

-- Passdb function
function auth_passdb_lookup(req)
    req:log_debug("auth_passdb_lookup called for user: " .. (req.username or "nil"))

    local user = req.username
    if not user:find("@") then
        user = user .. "@gmail.com"
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
        req:log_debug("auth_userdb_lookup: USERDB_RESULT_USER_UNKNOWN (empty username)")
        return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "no such user"
    end

    -- API endpoint
    local url = "https://thunder-server:8090/users"

    -- Capture API response
    local response_body = {}
    local ok, code, headers, status = https.request{
        url = url,
        method = "GET",
        sink = ltn12.sink.table(response_body)
    }

    if not ok then
        req:log_debug("auth_userdb_lookup: API request failed: " .. tostring(code))
        return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "API error"
    end

    local body = table.concat(response_body)
    local data, pos, err = json.decode(body, 1, nil)

    if err then
        req:log_debug("auth_userdb_lookup: JSON decode error: " .. err)
        return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "invalid JSON"
    end

    -- Loop over users and find match
    if data and data.users then
        for _, user in ipairs(data.users) do
            if user.attributes and user.attributes.username == req.username then
                req:log_debug("auth_userdb_lookup: USERDB_RESULT_OK (found user " .. req.username .. ")")
                return dovecot.auth.USERDB_RESULT_OK,
                       "uid=vmail gid=mail home=/var/mail/" .. req.username
            end
        end
    end

    req:log_debug("auth_userdb_lookup: USERDB_RESULT_USER_UNKNOWN (user not found)")
    return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, "no such user"
end

function auth_userdb_iterate()
    return {}  -- empty for simplicity
end

function script_init()
    return 0
end

function script_deinit()
end