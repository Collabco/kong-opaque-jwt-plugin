local TokenHandler = {
  VERSION  = "1.0.0",
  PRIORITY = 1006,
}

local kong = kong
local access = require "kong.plugins.kong-opaque-jwt.access"

function TokenHandler:new()
  TokenHandler.super.new(self, "kong-opaque-jwt")
end

function TokenHandler:access(config)
  TokenHandler.super.access(self)

  access.execute(config)

end


return TokenHandler
