package = "kong-opaque-jwt"
version = "2.1-3"
source = {
   url = "git+https://github.com/Collabco/kong-opaque-jwt.git"
}
description = {
   summary = "A plugin for Kong which validates and replaces an opaque token with a newly signed JWT containing claims obtained through introspection.",
   homepage = "https://github.com/Collabco/kong-opaque-jwt.git",
   license = "Apache 2.0"
}
dependencies = {}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.kong-opaque-jwt.access"] = "src/access.lua",
      ["kong.plugins.kong-opaque-jwt.api"] = "src/api.lua",
      ["kong.plugins.kong-opaque-jwt.handler"]  = "src/handler.lua",
      ["kong.plugins.kong-opaque-jwt.schema"]= "src/schema.lua",
      ["kong.plugins.kong-opaque-jwt.jwt"]= "src/jwt.lua"
   }
}
