local _M = { conf = {} }
local http = require "resty.http"
local pl_stringx = require "pl.stringx"
local cjson = require "cjson.safe"
local jwt = require "kong.plugins.kong-opaque-jwt.jwt"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"

--- Create an error response payload
-- @param message to reply with
-- @param status code to response with
local function error_response(message, status)
    local jsonStr = '{"status":' .. status .. ',"detail":"' .. message .. '"}'
    ngx.header['Content-Type'] = 'application/json'
    ngx.status = status
    ngx.say(jsonStr)
    ngx.exit(status)
end

--- Create introspection request
-- @param access_token to introspect
local function introspect_access_token_req(access_token)
    local httpc = http:new()

    -- Generate Authorization header value using client id and client secret
    local auth_header = "Basic " .. ngx.encode_base64(_M.conf.introspection_client_id .. ":" .. _M.conf.introspection_client_secret)

    local res, err = httpc:request_uri(_M.conf.introspection_url, {
        method = "POST",
        ssl_verify = false,
        body = "token_type_hint=access_token&token=" .. access_token,
        headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Authorization"] = auth_header }
    })

    if not res then
        return { status = 0 }
    end
    if res.status ~= 200 then
        return { status = res.status }
    end
    return { status = res.status, body = res.body }
end

--- Introspect the access token
-- @param access_token to introspect
local function introspect_access_token(access_token)
    if _M.conf.introspection_result_cache_time > 0 then
        -- Generate cache key using access token and introspection client id to ensure unique
        local cache_id = "at:" .. access_token .. ":" .. _M.conf.introspection_client_id
        local res, err = kong.cache:get(cache_id, { ttl = _M.conf.introspection_result_cache_time },
            introspect_access_token_req, access_token)
        if err then
            return { status = 500 }
        end
        -- not 200 response status isn't valid for normal caching
        if res.status ~= 200 then
            kong.cache:invalidate_local(cache_id)
        end

        return res
    end

    return introspect_access_token_req(access_token)
end



--- Is the scope in introspected response allowed
-- @param scope to check
local function is_scope_authorized(scope)
    if _M.conf.introspection_required_scope == nil then
        return true
    end
    local needed_scope = pl_stringx.strip(_M.conf.introspection_required_scope)
    if string.len(needed_scope) == 0 then
        return true
    end
    scope = pl_stringx.strip(scope)
    if string.find(scope, '*', 1, true) or string.find(scope, needed_scope, 1, true) then
        return true
    end

    return false
end

--- Check access token is a jwt
local function is_jwt_access_token(token)
    local jwt, err = jwt_decoder:new(token)
    if err then
        return false
    else
        return true
    end
end

--- Checks token has Bearer prefix
local function is_bearer_access_token(token)
    local prefix = "bearer "
    local lowerToken = token:lower()
    return lowerToken:sub(1, #prefix) == prefix
end
--

--- Execute all plugin logic
-- @param conf the configuration
function _M.execute(conf)
    _M.conf = conf

    -- check if preflight request and whether it should be authenticated
    if not conf.run_on_preflight and kong.request.get_method() == "OPTIONS" then
        return
    end

    local access_token = ngx.req.get_headers()["Authorization"]
    
    -- If no access token provided either allow the request to continue (bypass the plugin if configuration allows) or reject as unauthorised.
    if not access_token then
        if conf.allow_unauthenticated_access then
            return
        else
            error_response("Authentication is required.", ngx.HTTP_UNAUTHORIZED)
            return
        end 
    end

    -- If configured to allow non-bearer token authorization headers and a Authorization header is provided that does not have 'Bearer' prefix then allow request to continue and  bypass this plug-in
    if conf.allow_non_bearer_authorization_header then
        if not is_bearer_access_token(access_token) then
            return
        end
    end

    -- remove Bearer prefix to assign access token
    access_token = pl_stringx.replace(access_token, "Bearer ", "", 1)

    -- If configured to do so and the provided token is a JWT then ignore the request and bypass the plugin
    if conf.ignore_jwt and is_jwt_access_token(access_token) then
        return
    end

    local res = introspect_access_token(access_token)
    if not res then
        error_response("Authorization server error", ngx.HTTP_INTERNAL_SERVER_ERROR)
        return
    end
    if res.status == 500 then
        error_response("Authorization server error", ngx.HTTP_INTERNAL_SERVER_ERROR)
        return
    end
    if res.status ~= 200 then
        error_response("The resource owner or authorization server denied the request.", ngx.HTTP_UNAUTHORIZED)
        return
    end
    local data = cjson.decode(res.body)
    if data["active"] ~= true then
        error_response("The resource owner or authorization server denied the request.", ngx.HTTP_UNAUTHORIZED)
        return
    end
    if not is_scope_authorized(data["scope"]) then
        error_response("Forbidden", ngx.HTTP_FORBIDDEN)
        return
    end

    -- clear opaque token header from request
    ngx.req.clear_header("Authorization")

    -- create jwt from introspection response payload
    local jwt_token = jwt.create_jwt(conf, data)

    -- set jwt token header in request
    ngx.req.set_header("Authorization", "Bearer " .. jwt_token)
    
    -- if auth signature header specific generate and set.
    if conf.auth_signature_header_name then

        local auth_sig = ""

        -- concatenate claims with pipe as required
        if conf.auth_signature_claim_1 and data[conf.auth_signature_claim_1] then
            auth_sig = auth_sig .. (auth_sig ~= "" and "|" or "")  .. data[conf.auth_signature_claim_1]
        end

        if conf.auth_signature_claim_2 and data[conf.auth_signature_claim_2] then
            auth_sig = auth_sig .. (auth_sig ~= "" and "|" or "")  .. data[conf.auth_signature_claim_2]
        end

        if conf.auth_signature_claim_3 and data[conf.auth_signature_claim_3] then
            auth_sig = auth_sig .. (auth_sig ~= "" and "|" or "")  .. data[conf.auth_signature_claim_3]
        end

        -- set authentication signature response header for the request
        kong.response.set_header(conf.auth_signature_header_name, auth_sig)

    end

end

return _M