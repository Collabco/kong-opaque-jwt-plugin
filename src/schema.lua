local typedefs = require "kong.db.schema.typedefs"
local url = require "socket.url"

local function validate_url(value)
    local parsed_url = url.parse(value)
    if parsed_url.scheme and parsed_url.host then
        parsed_url.scheme = parsed_url.scheme:lower()
        if not (parsed_url.scheme == "https" or parsed_url.scheme == "http") then
            return false, "Supported protocols are HTTP and HTTPS"
        end
    end

    return true
end

return {
    name = "kong-opaque-jwt",
    fields = {
        {
            -- this plugin will only be applied to Services or Routes
            consumer = typedefs.no_consumer
        },
        {
            -- this plugin will only run within Nginx HTTP module
            protocols = typedefs.protocols_http
        },
        { 
            -- define the configuration fields that can be setup
            config = {
                type = "record",
                fields = {
                    { allow_unauthenticated_access = { type = "boolean", required = true, default = false } },
                    { allow_non_bearer_authorization_header = { type = "boolean", required = true, default = false } },
                    { ignore_jwt = { type = "boolean", required = true, default = false } },
                    { introspection_url = { type = "string", required = true, custom_validator = validate_url } },
                    { introspection_client_id = { type = "string", required = true } },
                    { introspection_client_secret = { type = "string", required = true } },
                    { introspection_result_cache_time = { type = "number", required = true, default = 0 } },
                    { introspection_required_scope = { type = "string", required = false } },
                    { jwt_signing_kid = { type = "string", required = false } },
                    { jwt_signing_x5t = { type = "string", required = false } },
                    { jwt_signing_include_x5c = { type = "boolean", required = true, default = false } },
                    { jwt_signing_private_key_location = { type = "string", required = false } },
                    { jwt_signing_public_key_location = { type = "string", required = false } },
                    { jwt_signing_token_ttl = { type = "number", required = true, default = 0 } },
                    { run_on_preflight = { type = "boolean", required = true, default = false } },
                    { auth_signature_header_name = { type = "string", required = false } },
                    { auth_signature_claim_1 = { type = "string", required = false, default = "tenant" } },
                    { auth_signature_claim_2 = { type = "string", required = false, default = "sub" } },
                    { auth_signature_claim_3 = { type = "string", required = false, default = "sid" } }

                }
            }
        }
    }
}