local TextOperation = require 'ot.text-operation'
local Server = require 'ot.server'
local Client = require 'ot.client'
local MemoryBackend = require 'ot.memory-backend'
require 'test/helpers'


local MyClient = setmetatable({}, { __index = Client })
MyClient.__index = MyClient

function MyClient.new(revision, id, document, channel)
  local inst = Client.new(revision)
  setmetatable(inst, MyClient)
  inst.id = id
  inst.document = document
  inst.channel = channel
  return inst
end

function MyClient:sendOperation(revision, operation)
  self.channel:write({self.id, revision, operation})
end

function MyClient:applyOperation(operation)
  self.document = operation(self.document)
end

function MyClient:performOperation()
  local operation = randomOperation(self.document)
  self.document = operation(self.document)
  self:applyClient(operation)
end


-- Mock a FIFO network connection.
local NetworkChannel = {}
NetworkChannel.__index = NetworkChannel

function NetworkChannel.new(onReceive)
  return setmetatable({ buffer = {}, onReceive = onReceive }, NetworkChannel)
end

function NetworkChannel:isEmpty()
  return #self.buffer == 0
end

function NetworkChannel:write(msg)
  table.insert(self.buffer, msg)
end

function NetworkChannel:read()
  return table.remove(self.buffer, 1)
end

function NetworkChannel:receive()
  return self.onReceive(self:read())
end


local testClientServerInteraction = repeatTest(function()
  local document = randomString()
  local server = Server.new(document, MemoryBackend.new())

  local alice, aliceReceiveChannel, aliceSendChannel
  local bob, bobReceiveChannel, bobSendChannel

  local function serverReceive(msg)
    local clientId, revision, operation = unpack(msg)
    local operationPrime = server:receiveOperation(revision, operation)
    local msg = {clientId, operationPrime}
    aliceReceiveChannel:write(msg)
    bobReceiveChannel:write(msg)
  end

  local function clientReceive(client)
    return function(msg)
      local clientId, operation = unpack(msg)
      if clientId == client.id then
        client:serverAck()
      else
        client:applyServer(operation)
      end
    end
  end

  aliceSendChannel = NetworkChannel.new(serverReceive)
  alice = MyClient.new(0, "alice", document, aliceSendChannel)
  aliceReceiveChannel = NetworkChannel.new(clientReceive(alice))

  bobSendChannel = NetworkChannel.new(serverReceive)
  bob = MyClient.new(0, "bob", document, bobSendChannel)
  bobReceiveChannel = NetworkChannel.new(clientReceive(bob))

  local channels = {
    aliceSendChannel,
    aliceReceiveChannel,
    bobSendChannel,
    bobReceiveChannel
  }

  local function canReceive()
    for i=1, #channels do
      if not channels[i]:isEmpty() then
        return true
      end
    end
    return false
  end

  local function receiveRandom()
    local filtered = {}
    for i=1, #channels do
      if not channels[i]:isEmpty() then
        table.insert(filtered, channels[i])
      end
    end
    randomElement(filtered):receive()
  end

  local n = 64
  while n > 0 do
    if not canReceive() or math.random() < 0.75 then
      client = randomElement({alice, bob})
      client:performOperation()
    else
      receiveRandom()
    end
    n = n - 1
  end

  while canReceive() do
    receiveRandom()
  end

  assert(server.document == alice.document)
  assert(server.document == bob.document)
end)

return testClientServerInteraction