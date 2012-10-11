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

  local function genRetain()
    local r = 1 + randomInt(maxLen)
    i = i + r
    o:retain(r)
  end

  local function getInsert()
    o:insert(randomChar() .. randomString(9))
  end

  local function genDelete()
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

function repeatTest(test, n)
  n = n or 64
  return function (...)
    for i=1,n do
      test(...)
    end
  end
end
