-- Simple backend that saves all operations in the server's memory. This
-- causes the processe's heap to grow indefinitely.
local MemoryBackend = {}
MemoryBackend.__index = MemoryBackend

function MemoryBackend.new(operations)
  return setmetatable({ operations = operations or {}}, MemoryBackend)
end

-- Save an operation in the database
function MemoryBackend:saveOperation(operation)
  table.insert(self.operations, operation)
end

-- Return operations in a given range. Note that the first operation has the
-- revision 0 and the end revision is exclusive.
function MemoryBackend:getOperations(start, last)
  if last == nil then
    last = #self.operations
  else
    last = last - 1
  end

  local operations = {}
  for i=start + 1, last do
    table.insert(operations, self.operations[i])
  end
  return operations
end

return MemoryBackend