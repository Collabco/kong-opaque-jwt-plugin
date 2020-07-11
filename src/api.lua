
-- Function to get unique introspection_client_id values from all plugins which are loaded from the database
local function get_plugin_client_ids_from_database()

    local clientid_flags = {}
    local clientids = {}

    for plugin, err in kong.db.plugins:each(1000) do
        if err then
          kong.log.err("Error when iterating over plugin credentials: " .. err)
          return nil, err
        end

        local client_id = plugin.config.introspection_client_id
        if plugin.name == "kong-opaque-jwt" and (not clientid_flags[client_id]) then
            table.insert(clientids, client_id)
            clientid_flags[client_id] = true
        end
      
    end

    return clientids, nil
end

-- Function to get unique introspection_client_id values from all plugins which are loaded from the cache first, then database
local function get_plugin_client_ids()
    local cache_id = "kong-opaque-jwt-clientids"
    local clientids, err = kong.cache:get(cache_id, { ttl = 60}, get_plugin_client_ids_from_database)

    -- Let's not cache errors so invalidate
    if err then
        kong.cache:invalidate(cache_id)
    end

    return clientids, err 
end

-- API endpoint to invalidate a token from the kong cache by making a DELETE request to /kong-opaque-jwt with a access_token in the body
return {
    ["/kong-opaque-jwt"] = {
            DELETE = function(self)
                local access_token = self.params.access_token

                if(access_token) then
                    -- Get client ids to invalidate cached access_token for
                    local clientids, err = get_plugin_client_ids()

                    if err then
                        return kong.response.exit(500, { status = "500", detail = "Failed to fetch plugin configurations from database." })
                    end

                    -- Enumerate clientids and invalidate the access tokens for each one
                    for _,clientid in ipairs(clientids) do
                        kong.cache:invalidate("at:" .. access_token .. ":" .. clientid)
                    end
                    return { json = { status = "200", detail = "Token evicted from cache"} }
                else
                    return kong.response.exit(400, { status = "400", detail = "'access_token' must be submitted in the request query string / body." })
                end
            end
    },
}