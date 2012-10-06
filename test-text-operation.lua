local TextOperation = require "text-operation"

function randomInt(max)
  return math.floor(math.random() * max)
end

function randomChar()
  return string.char(97 + randomInt(26))
end

function randomString(maxLen)
  maxLen = maxLen or 16
  local s = ''
  local sLen = randomInt(maxLen + 1)
  while sLen > 0 do
    s = s .. randomChar()
    sLen = sLen - 1
  end
  return s
end

function randomElement(t)
  return t[1 + randomInt(#t)]
end

function randomOperation(doc)
  local o = TextOperation()
  local i = 0
  local maxLen

  function genRetain()
    local r = 1 + randomInt(maxLen)
    i = i + r
    o:retain(r)
  end

  function getInsert()
    o:insert(randomChar() .. randomString(9))
  end

  function genDelete()
    local d = 1 + randomInt(maxLen)
    i = i + d
    o:delete(d)
  end

  while i < #doc do
    maxLen = math.min(10, #doc - i)
    randomElement({genRetain, getInsert, genDelete})()
  end

  return o
end

function repeatTest (test)
  return function (...)
    for i=1,50 do
      test(...)
    end
  end
end

function testAppend()
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

local testLenDifference = repeatTest(function ()
  local doc = randomString(50)
  local operation = randomOperation(doc)
  assert(#operation(doc) - #doc == operation:lenDifference())
end)

function testApply()
  local doc = "Lorem ipsum"
  local operation = TextOperation():delete(1):insert("l"):retain(4):delete(4):retain(2):insert("s")
  assert(operation(doc) == "loremums")
end

local testInvert = repeatTest(function ()
  local doc = randomString(50)
  local operation = randomOperation(doc)
  local inverse = operation:invert(doc)
  assert(doc == inverse(operation(doc)))
end)

local testCompose = repeatTest(function ()
  local doc = randomString(50)
  local a = randomOperation(doc)
  local docA = a(doc)
  local b = randomOperation(docA)
  local ab = a:compose(b)
  assert(b(docA) == ab(doc))
end)

local testTransform = repeatTest(function ()
  local doc = randomString(50)
  local a = randomOperation(doc)
  local b = randomOperation(doc)
  aPrime, bPrime = TextOperation.transform(a, b)
  assert(aPrime(b(doc)) == bPrime(a(doc)))
end)

function test()
  testAppend()
  testLenDifference()
  testApply()
  testInvert()
  testCompose()
  testTransform()
end

test()