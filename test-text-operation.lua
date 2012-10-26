local TextOperation = require "text-operation"
require "test-helpers"

local testJsonId = repeatTest(function()
  local doc = randomString()
  local operation = randomOperation(doc)
  local operation2 = TextOperation.fromJSON(operation:toJSON())
  assert(operation == operation2)
end)

local function testAppend()
  o = TextOperation()
    :delete(0)
    :insert("lorem")
    :retain(0)
    :insert(" ipsum")
    :retain(3)
    :insert("")
    :retain(5)
    :delete(8)
  assert(#o.ops == 3)
  assert(o == TextOperation({"lorem ipsum", 8, -8}))
end

local testLenDifference = repeatTest(function()
  local doc = randomString(50)
  local operation = randomOperation(doc)
  assert(#operation(doc) - #doc == operation:lenDifference())
end)

local function testApply()
  local doc = "Lorem ipsum"
  local operation = TextOperation():delete(1):insert("l"):retain(4):delete(4):retain(2):insert("s")
  assert(operation(doc) == "loremums")
end

local testInvert = repeatTest(function()
  local doc = randomString(50)
  local operation = randomOperation(doc)
  local inverse = operation:invert(doc)
  assert(doc == inverse(operation(doc)))
end)

local testCompose = repeatTest(function()
  local doc = randomString(50)
  local a = randomOperation(doc)
  local docA = a(doc)
  local b = randomOperation(docA)
  local ab = a:compose(b)
  assert(b(docA) == ab(doc))
end)

local testTransform = repeatTest(function()
  local doc = randomString(50)
  local a = randomOperation(doc)
  local b = randomOperation(doc)
  aPrime, bPrime = TextOperation.transform(a, b)
  assert(aPrime(b(doc)) == bPrime(a(doc)))
end)

return function()
  testJsonId()
  testAppend()
  testLenDifference()
  testApply()
  testInvert()
  testCompose()
  testTransform()
end