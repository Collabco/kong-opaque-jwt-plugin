# Kong opaque-jwt plugin

## Overview 
This is a plugin for Kong which validates and replaces an opaque token with a newly signed JWT containing claims obtained through introspection.

The plugin will cache the introspection response payload of active tokens for a configured duration of time. Additionally the plugin exposes an endpoint on the kong admin api to manually invalidate the cache which can be used for use-cases such as 'triggering expiration of cached token when the token is revoked'.

The signed JWT generated has a body containing the full payload of the introspection response.

The kong server/docker image needs to have the signing certificate public key and private key to be able to create a signed JWT token. This signing certificate should be the same as used in the OAuth 2 authorization server.

## Supported Kong Releases
Tested with Kong >= 1.2.x (probably will work with older versions)

## Build / Installation

### Build

`luarocks make` -  Will build the lua package and install

`luarocks pack kong-opaque-jwt 1.0-1` - Will package the installed package for installation on another server/container.

### Install

1. Install plug-in using luarocks package - `luarocks install kong-opaque-jwt-1.0-0.all.rock` - install file specified i.e. kong-opaque-jwt-1.0.0.all.rock
2. Add to `kong.conf` configuration file plugins directive i.e. `plugins = bundled,kong-opaque-jwt`
3. If necessary update `lua_package_path` e.g `lua_package_path = /usr/local/Cellar/openresty@1.15.8.3/1.15.8.3/luarocks/share/lua/5.1/?.lua;;` (default luarocks install path on a mac kong install)

### Configuration

| Configuration Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `config.allow_unauthenticated_access`    | yes | false | If set to true and no authorization header is provided allow requests to continue, bypassing the plug-in |
| `config.allow_non_bearer_authorization_header`    | yes | false | If set to true and Basic (or other) authentication is used allow requests to continue, bypassing the plug-in |
| `config.ignore_jwt`    | yes | false | If set to true and a JWT is provided allow requests to continue, bypassing the plug-in |
| `config.introspection_url`    | yes | | External introspection endpoint url compatible with RFC7662. |
| `config.introspection_client_id`  | yes |  | client id used to authenticate to introspection endpoint. |
| `config.introspection_client_secret`  | yes |  | client secret used to authenticate to introspection endpoint. |
| `config.introspection_result_cache_time` | yes | 0 | Number of seconds to cache introspection response (in seconds if greater than '0' - the default) |
| `config.introspection_required_scope` | no | |  Scope that token need to be authorized. For example 'profile'. Any scopes will be authorised if empty. |
| `config.jwt_signing_kid`  | no | | 'kid' attribute value to be injected into the JWT header. |
| `config.jwt_signing_x5t`  | no | | 'x5t' attribute value to be injected into the JWT header. |
| `config.jwt_signing_include_x5c` | yes | false | If true the public key of the signing certificate will be injected as 'x5c' attribute in the JWT header. |
| `config.jwt_signing_private_key_location` | no | | Location of private key .pem file on the filesystem. |
| `config.jwt_signing_public_key_location`  | no | | Location of public key .pem file on the filesystem. |
| `config.jwt_signing_token_ttl`  | yes | 0 | Override 'exp' attribute (token expiry time in seconds) provided by introspection endpoint if value is greater than '0' - the default.) |
| `config.run_on_preflight`  | yes | false | If true then the plug-in will run on pre-flight (OPTIONS) requests. By default this is false as these aren't usually authenticated. |

### JWT Signing certificates

The JWT signing certificate needs to be presented as two seperate Base 64 encoded '.pem' files in the container/server file-system.

The location of these files can be specified using the following configuration attributes or alertnatively environment variables.

| File | Configuration parameter | Environment variable |
| --- | --- | --- |
| Public key / certificate | `config.jwt_signing_public_key_location` | `KONG_JWT_SIGNING_CERT` |
| Private key file | `config.jwt_signing_private_key_location` | `KONG_JWT_SIGNING_KEY` |

### 'test' folder = Running locally

No integration tests yet but you can test manually with kong and echo-server and your authorization server...

- Ensure you current directory is the root of this repos.
- [Install kong](https://konghq.com/get-started/#install) e.g. on a mac terminal (you need hombrew) - `brew tap kong/kong && brew install kong`
- Install the plugin - `luarocks make`
- Modify the plugin configuration in test/kong.yml
- Install echo server - `npm install -g http-echo-server` (requires npm and nodejs)
- Run echo server - `http-echo-server 3005`
- Start kong `kong start -c ./test/kong.conf`
- Use curl or your favourite postman like rest client to make requests to http://localhost:8000 with and without bearer tokens and observe substitution of your Authorization header.

## Limitations
1. Currently the plugin requires introspection client id and secret which is more open id connect 1.0 than OAuth 2 but I've been exclusively working with an open id connect 1.0 authorization server.
2. jwt_signing_kid and jwt_signing_x5t configuration items could probably be deduced automatically from the signing certificate.
3. Currrently no integration tests which are little beyond my lua skills and need more time which i may put in eventually.

## Future potential 
It is possible to enhance the plug-in in the following ways:

1. It could both validate JWT and introspect opaque tokens.
2. It could look-up and assign kong consumers allowing authorization to take place in Kong becoming a general purpose authentication plug-in.
3. It could pass claims onto upstream API services via headers removing need to implement JWT authorization at the API in some cases.