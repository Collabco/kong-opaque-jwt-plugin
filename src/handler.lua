local BasePlugin = require "kong.plugins.base_plugin"


local kong = kong
local access = require "kong.plugins.kong-opaque-jwt.access"

local TokenHandler = BasePlugin:extend()


TokenHandler.VERSION  = "1.0.0"
TokenHandler.PRIORITY = 1006 -- Set to run above all other authenticatoin plug-ins


function TokenHandler:new()
  TokenHandler.super.new(self, "kong-opaque-jwt")
end


function TokenHandler:access(config)
  TokenHandler.super.access(self)

  access.execute(config)

end


return TokenHandler
