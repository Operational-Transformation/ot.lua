-- I have adopted the naming convention from Daniel Spiewak's CCCP:
-- https://github.com/djspiewak/cccp/blob/master/agent/src/main/scala/com/codecommit/cccp/agent/state.scala

-- Handles the client part of the OT synchronization protocol. Transforms
-- incoming operations from the server, buffers operations from the user and
-- sends them to the server at the right time.

local Client, synchronized, AwaitingConfirm, AwaitingWithBuffer

Client = {}
Client.__index = Client

function Client.new(revision)
  return setmetatable({ revision = revision, state = synchronized }, Client)
end

-- Call this method when the user (!) changes the document.
function Client:applyClient(operation)
  self.state = self.state:applyClient(self, operation)
end

-- Call this method with a new operation from the server.
function Client:applyServer(operation)
  self.revision = self.revision + 1
  self.state = self.state:applyServer(self, operation)
end

-- Call this method when the server acknowledges an operation send by the
-- current user (via the send_operation method)
function Client:serverAck()
  self.revision = self.revision + 1
  self.state = self.state:serverAck(self)
end

-- Should send an operation and its revision number to the server."""
function Client:sendOperation(revision, operation)
  error("You have to override 'send_operation' in your Client child class")
end

-- Should apply an operation from the server to the current document."""
function Client:applyOperation(operation)
  error("You have to overrid 'apply_operation' in your Client child class")
end

-- In the 'Synchronized' state, there is no pending operation that the client
-- has sent to the server.
synchronized = {}

function synchronized:applyClient(client, operation)
  -- When the user makes an edit, send the operation to the server and switch
  -- to the 'AwaitingConfirm' state
  client:sendOperation(client.revision, operation)
  return AwaitingConfirm.new(operation)
end

function synchronized:applyServer(client, operation)
  -- When we receive a new operation from the server, the operation can be
  -- simply applied to the current document
  client:applyOperation(operation)
  return self
end

function synchronized:serverAck(client)
  error("There is no pending operation")
end


-- In the 'AwaitingConfirm' state, there's one operation the client has sent
-- to the server and is still waiting for an acknowledgement.
AwaitingConfirm = {}
AwaitingConfirm.__index = AwaitingConfirm

function AwaitingConfirm.new(outstanding)
  -- Save the pending operation
  return setmetatable({ outstanding = outstanding }, AwaitingConfirm)
end

function AwaitingConfirm:applyClient(client, operation)
  -- When the user makes an edit, don't send the operation immediately, instead
  -- switch to the 'AwaitingWithBuffer' state
  return AwaitingWithBuffer.new(self.outstanding, operation)
end

function AwaitingConfirm:applyServer(client, operation)
  --                   /\
  -- self.outstanding /  \ operation
  --                 /    \
  --                 \    /
  --  operation_p     \  / outstanding_p (new self.outstanding)
  --  (can be applied  \/
  --  to the client's
  --  current document)
  Operation = getmetatable(self.outstanding)
  outstandingP, operationP = Operation.transform(self.outstanding, operation)
  client:applyOperation(operationP)
  return AwaitingConfirm.new(outstandingP)
end

function AwaitingConfirm:serverAck(client)
  return synchronized
end


-- In the 'AwaitingWithBuffer' state, the client is waiting for an operation
-- to be acknowledged by the server while buffering the edits the user makes
AwaitingWithBuffer = {}
AwaitingWithBuffer.__index = AwaitingWithBuffer

function AwaitingWithBuffer.new(outstanding, buffer)
  -- Save the pending operation and the user's edits since then
  return setmetatable({ outstanding = outstanding, buffer = buffer }, AwaitingWithBuffer)
end

function AwaitingWithBuffer:applyClient(client, operation)
  -- Compose the user's changes onto the buffer
  local newBuffer = self.buffer:compose(operation)
  return AwaitingWithBuffer.new(self.outstanding, newBuffer)
end

function AwaitingWithBuffer:applyServer(client, operation)
  --                       /\
  --     self.outstanding /  \ operation
  --                     /    \
  --                    /\    /
  --       self.buffer /  \* / outstanding_p
  --                  /    \/
  --                  \    /
  --      operation_pp \  / buffer_p
  --                    \/
  -- the transformed
  -- operation -- can
  -- be applied to the
  -- client's current
  -- document
  --
  -- * operation_p
  local Operation = getmetatable(self.outstanding)
  outstandingP, operationP = Operation.transform(self.outstanding, operation)
  bufferP, operationPP = Operation.transform(self.buffer, operationP)
  client:applyOperation(operationPP)
  return AwaitingWithBuffer.new(outstandingP, bufferP)
end

function AwaitingWithBuffer:serverAck(client)
  -- The pending operation has been acknowledged
  -- => send buffer
  client:sendOperation(client.revision, self.buffer)
  return AwaitingConfirm.new(self.buffer)
end


return Client