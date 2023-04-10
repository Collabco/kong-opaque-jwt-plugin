local TokenHandler = {
  VERSION  = "1.0.0",
  PRIORITY = 1006,
}

local kong = kong
local access = require "kong.plugins.kong-opaque-jwt.access"

function TokenHandler:access(config)

  access.execute(config)

end


return TokenHandler
