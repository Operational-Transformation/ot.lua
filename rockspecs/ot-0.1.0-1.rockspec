package = "ot"
version = "0.1.0-1"
source = {
  url = "http://cloud.github.com/downloads/Operational-Transformation/ot.lua/ot.lua-0.1.0-1.tar.gz"
}
description = {
  summary = "Real-time collaborative editing with Operational Transformation",
  detailed = [[
    Real-time collaborative editing with Operational Transformation
  ]],
  homepage = "https://github.com/Operational-Transformation/ot.lua",
  license = "MIT/X11"
}
dependencies = {
  "lua >= 5.1"
}

build = {
  type = "none",
  install = {
    lua = {
      ["ot.text-operation"] = "src/text-operation.lua",
      ["ot.client"]         = "src/client.lua",
      ["ot.server"]         = "src/server.lua",
      ["ot.memory-backend"] = "src/memory-backend.lua"
    }
  }
}
