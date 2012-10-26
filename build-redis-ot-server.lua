#!/usr/bin/env lua

local redisCode = [[
local function reverse(t)
  local reversed = {}
  for i=#t, 1, -1 do
    table.insert(reversed, t[i])
  end
  return reversed
end

local function main()
  local documentKey = KEYS[1]
  local operationsKey = KEYS[2]
  local currentRevision = redis.call("LLEN", operationsKey)

  if #ARGV == 0 then
    return {redis.call("GET", documentKey), currentRevision}
  end

  local revision = tonumber(ARGV[1], 10)
  local concurrentOperations
  if currentRevision < revision then
    return redis.error_reply("Revision is greater than any known revision.")
  elseif currentRevision > revision then
    concurrentOperations = reverse(redis.call("LRANGE", operationsKey, 0, currentRevision - revision - 1))
  else
    concurrentOperations = {}
  end
  redis.log(redis.LOG_DEBUG, "HALLO WELT!" .. revision)

  if #ARGV == 1 then
    return concurrentOperations
  end

  local operation = TextOperation.fromJSON(cjson.decode(ARGV[2]))
  for i=1, #concurrentOperations do
    local concurrentOperation = TextOperation.fromJSON(cjson.decode(concurrentOperations[i]))
    operation = TextOperation.transform(operation, concurrentOperation)
  end

  local document = redis.call("GET", documentKey) or ""
  document = operation(document)
  redis.call("SET", documentKey, document)

  local jsonOperation = cjson.encode(operation:toJSON())
  redis.call("LPUSH", operationsKey, jsonOperation)
  table.insert(concurrentOperations, jsonOperation)
  return concurrentOperations
end

return main()
]]

function main()
  local outputFilename = "redis-ot-server.lua"
  local outputFile = io.open(outputFilename, "w+")

  function includeFile(filename, moduleName)
    outputFile:write("local " .. moduleName .. " = (function()\n")
    for line in io.lines(filename) do
      outputFile:write("  ", line, "\n")
    end
    outputFile:write("end)()\n")
  end

  includeFile("text-operation.lua", "TextOperation")
  outputFile:write("\n", redisCode)
end

main()