-- Receives operations from clients, transforms them against all
-- concurrent operations and sends them back to all clients.
local Server = {}
Server.__index = Server

function Server.new(document, backend)
  return setmetatable({ document = document, backend = backend }, Server)
end

-- Transforms an operation coming from a client against all concurrent
-- operation, applies it to the current document and returns the operation to
-- send to the clients.
function Server:receiveOperation(revision, operation)
  local Operation = getmetatable(operation)

  local concurrentOperations = self.backend:getOperations(revision)
  for i=1, #concurrentOperations do
    operation = Operation.transform(operation, concurrentOperations[i])
  end

  self.document = operation(self.document)
  self.backend:saveOperation(operation)
  return operation
end

return Server