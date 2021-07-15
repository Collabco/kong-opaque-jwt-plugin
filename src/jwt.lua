local resty_sha256 = require "resty.sha256"
local str = require "resty.string"
local pl_file = require "pl.file"
local json = require "cjson"
local openssl_digest = require "resty.openssl.digest"
local openssl_pkey = require "resty.openssl.pkey"
local table_concat = table.concat
local encode_base64 = ngx.encode_base64
local env_private_key_location = os.getenv("KONG_JWT_SIGNING_KEY")
local env_public_key_location = os.getenv("KONG_JWT_SIGNING_CERT")
local utils = require "kong.tools.utils"
local _M = {}

--- Get the private key location either from the environment or from configuration
-- @param conf the kong configuration
-- @return the private key location
local function get_private_key_location(conf)
  if env_private_key_location then
    return env_private_key_location
  end
  return conf.jwt_signing_private_key_location
end

--- Get the public key location either from the environment or from configuration
-- @param conf the kong configuration
-- @return the public key location
local function get_public_key_location(conf)
  if env_public_key_location then
    return env_public_key_location
  end
  return conf.jwt_signing_public_key_location
end

--- base 64 encoding
-- @param input String to base64 encode
-- @return Base64 encoded string
local function b64_encode(input)
  local result = encode_base64(input)
  result = result:gsub("+", "-"):gsub("/", "_"):gsub("=", "")
  return result
end

--- Read contents of file from given location
-- @param file_location the file location
-- @return the file contents
local function read_from_file(file_location)
  local content, err = pl_file.read(file_location)
  if not content then
    ngx.log(ngx.ERR, "Could not read file contents", err)
    return nil, err
  end
  return content
end

--- Get the Kong key either from cache or the given `location`
-- @param key the cache key to lookup first
-- @param location the location of the key file
-- @return the key contents
local function get_kong_key(key, location)
  -- This will add a non expiring TTL on this cached value
  local pkey, err = kong.cache:get(key, { ttl = 0 }, read_from_file, location)

  if err then
    ngx.log(ngx.ERR, "Could not retrieve pkey: ", err)
    return
  end

  return pkey
end

--- Base64 encode the JWT token
-- @param payload the payload of the token
-- @param key the key to sign the token with
-- @return the encoded JWT token
local function encode_jwt_token(conf, payload, key)
  local header = {
    alg = "RS256",
    typ = "at+jwt"
  }

  if conf.jwt_signing_kid then
   header.kid = conf.jwt_signing_kid
  end

  if conf.jwt_signing_x5t then
    header.x5t = conf.jwt_signing_x5t
  end

  if conf.jwt_signing_include_x5c then
    header.x5c = { b64_encode(get_kong_key("pubder", get_public_key_location(conf))) }
  end

  local segments = {
    b64_encode(json.encode(header)),
    b64_encode(json.encode(payload))
  }
  local signing_input = table_concat(segments, ".")
  local digest, err1 = openssl_digest.new("sha256")

  if err1 then
    return err1
  end

  digest:update(signing_input)
  local pkey, err2 = openssl_pkey.new(key)

  if err2 then
    return err2
  end

  local signature, err3 = pkey:sign(digest)

  if err3 then
    return err3
  end

  segments[#segments+1] = b64_encode(signature)
  return err3, table_concat(segments, ".")
end

--- Add the JWT header to the request
-- @param conf the configuration
-- @param payload the payload for the jwt
function _M.create_jwt(conf, payload)
  -- If signing token ttl configured then overwrite 'exp' attribute
  if conf.jwt_signing_token_ttl > 0 then
    local current_time = ngx.time() -- Much better performance improvement over os.time() 
    payload.exp = current_time + conf.jwt_signing_token_ttl -- Overwrite expiry time to configured number seconds from current time
  end
  payload.jti = utils.uuid() -- Set a uuid for the request
  local kong_private_key = get_kong_key("pkey", get_private_key_location(conf))
  local err, jwt = encode_jwt_token(conf, payload, kong_private_key)
  return err, jwt
end

return _M