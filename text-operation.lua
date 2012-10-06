local TextOperation = {}
TextOperation.__index = TextOperation

function isRetain(op)
  return type(op) == "number" and op > 0
end

function isDelete(op)
  return type(op) == "number" and op < 0
end

function isInsert(op)
  return type(op) == "string"
end

function opLen(op)
  if type(op) == "string" then
    return #op
  elseif op < 0 then
    return -op
  else
    return op
  end
end

function shorten(op, by)
  if type(op) == "string" then
    return string.sub(op, 1 + by)
  elseif op < 0 then
    return op + by
  else
    return op - by
  end
end

function shortenOps(a, b)
  local lenA = opLen(a)
  local lenB = opLen(b)
  if lenA == lenB then
    return nil, nil
  elseif lenA > lenB then
    return shorten(a, lenB), nil
  else
    return nil, shorten(b, lenA)
  end
end

function TextOperation.new(ops)
  return setmetatable({ ops = ops or {} }, TextOperation)
end

setmetatable(TextOperation, {
  __call = function(_, ...)
    return TextOperation.new(...)
  end
})

function TextOperation:__eq(other)
  if #self.ops ~= #other.ops then
    return false
  end

  for i=1, #self.ops do
    if self.ops[i] ~= other.ops[i] then
      return false
    end
  end

  return true
end

function TextOperation:retain(n)
  local ops = self.ops
  if n ~= 0 then
    if isRetain(ops[#ops]) then
      ops[#ops] = ops[#ops] + n
    else
      table.insert(ops, n)
    end
  end
  return self
end

function TextOperation:insert(s)
  local ops = self.ops
  if #s ~= 0 then
    if isInsert(ops[#ops]) then
      ops[#ops] = ops[#ops] .. s
    else
      table.insert(ops, s)
    end
  end
  return self
end

function TextOperation:delete(n)
  local ops = self.ops
  if n ~= 0 then
    if n > 0 then
      n = -n
    end
    if isDelete(ops[#ops]) then
      ops[#ops] = ops[#ops] + n
    else
      table.insert(ops, n)
    end
  end
  return self
end

function TextOperation:lenDifference()
  local s = 0
  for i=1, #self.ops do
    local op = self.ops[i]
    if type(op) == "string" then
      s = s + #op
    elseif op < 0 then
      s = s + op
    end
  end
  return s
end

function TextOperation:__call(doc)
  local parts = {}
  local len = 1

  for i=1, #self.ops do
    op = self.ops[i]
    if isRetain(op) then
      if len + op > #doc + 1 then
        error("Cannot apply operation: operation is too long")
      end
      table.insert(parts, string.sub(doc, len, len + op - 1))
      len = len + op
    elseif isInsert(op) then
      table.insert(parts, op)
    else
      len = len - op
      if len > #doc + 1 then
        error("Cannot apply operation: operation is too long")
      end
    end
  end

  if len ~= #doc + 1 then
    error("Cannot apply operation: operation is too short")
  end

  return table.concat(parts, '')
end

function TextOperation:invert(doc)
  local len = 1
  local inverse = TextOperation()

  for i=1, #self.ops do
    local op = self.ops[i]
    if isRetain(op) then
      inverse:retain(op)
      len = len + op
    elseif isInsert(op) then
      inverse:delete(#op)
    else
      inverse:insert(string.sub(doc, len, len - op - 1))
      len = len - op
    end
  end

  return inverse
end

function TextOperation:compose(other)
  local ia = 1
  local ib = 1
  local operation = TextOperation()

  local a = nil
  local b = nil
  while true do
    if a == nil then
      a = self.ops[ia]
      ia = ia + 1
    end
    if b == nil then
      b = other.ops[ib]
      ib = ib + 1
    end

    if a == nil and b == nil then
      -- end condition: both operations have been processed
      break
    end

    if isDelete(a) then
      operation:delete(a)
      a = nil
    elseif isInsert(b) then
      operation:insert(b)
      b = nil
    elseif a == nil then
      error("Cannot compose operations: first operation is too short")
    elseif b == nil then
      error("Cannot compose operations: first operation is too long")
    else
      local minLen = math.min(opLen(a), opLen(b))
      if isRetain(a) and isRetain(b) then
        operation:retain(minLen)
      elseif isInsert(a) and isRetain(b) then
        operation:insert(string.sub(a, 1, minLen))
      elseif isRetain(a) and isDelete(b) then
        operation:delete(minLen)
      end
      -- remaining case: isInsert(a) and isDelete(b)
      -- in this case the delete op deletes the text that has been added
      -- by the insert operation and we don't need to do anything

      a, b = shortenOps(a, b)
    end
  end

  return operation
end

function TextOperation.transform(operationA, operationB)
  local ia = 1
  local ib = 1
  local aPrime = TextOperation()
  local bPrime = TextOperation()
  local a = nil
  local b = nil

  while true do
    if a == nil then
      a = operationA.ops[ia]
      ia = ia + 1
    end
    if b == nil then
      b = operationB.ops[ib]
      ib = ib + 1
    end

    if a == nil and b == nil then
      -- end condition: both operations have been processed
      break
    end

    if isInsert(a) then
      aPrime:insert(a)
      bPrime:retain(#a)
      a = nil
    elseif isInsert(b) then
      aPrime:retain(#b)
      bPrime:insert(b)
      b = nil
    elseif a == nil then
      error("Cannot compose operations: first operation is too short")
    elseif b == nil then 
      error("Cannot compose operations: first operation is too long")
    else
      local minLen = math.min(opLen(a), opLen(b))
      if isRetain(a) and isRetain(b) then
        aPrime:retain(minLen)
        bPrime:retain(minLen)
      elseif isDelete(a) and isRetain(b) then
        aPrime:delete(minLen)
      elseif isRetain(a) and isDelete(b) then
        bPrime:delete(minLen)
      end
      -- remaining case: _is_delete(a) and _is_delete(b)
      -- in this case both operations delete the same string and we don't
      -- need to do anything

      a, b = shortenOps(a, b)
    end
  end

  return aPrime, bPrime
end

return TextOperation