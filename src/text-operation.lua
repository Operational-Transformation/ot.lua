local TextOperation = {}
TextOperation.__index = TextOperation

-- Operation are essentially lists of ops. There are three types of ops:
--
-- * Retain ops: Advance the cursor position by a given number of characters.
--   Represented by positive ints.
-- * Insert ops: Insert a given string at the current cursor position.
--   Represented by strings.
-- * Delete ops: Delete the next n characters. Represented by negative ints.

local function isRetain(op)
  return type(op) == "number" and op > 0
end

local function isDelete(op)
  return type(op) == "number" and op < 0
end

local function isInsert(op)
  return type(op) == "string"
end

local function opLen(op)
  if type(op) == "string" then
    return #op
  elseif op < 0 then
    return -op
  else
    return op
  end
end

-- Shortens an op by the given number of characters
local function shorten(op, by)
  if type(op) == "string" then
    return string.sub(op, 1 + by)
  elseif op < 0 then
    return op + by
  else
    return op - by
  end
end

-- Shortens a pair of ops. The result will be a tuple where the shorter of the
-- both ops is replaced by null and the longer one is shorted by the length of
-- the shorter one.
local function shortenOps(a, b)
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

-- Constructs an empty operation
-- 
-- When an operation is applied to an input string, you can think of this as
-- if an imaginary cursor runs over the entire string and skips over some
-- parts, deletes some parts and inserts characters at some positions. These
-- actions (skip/delete/insert) are stored as an array in the "ops" property.
function TextOperation.new(ops)
  return setmetatable({ ops = ops or {} }, TextOperation)
end

setmetatable(TextOperation, {
  __call = function(_, ...)
    return TextOperation.new(...)
  end
})

-- Constructs a TextOperation from a JSON document.
function TextOperation.fromJSON(jsonOps)
  local operation = TextOperation.new()
  for i=1, #jsonOps do
    local jsonOp = jsonOps[i]
    if isRetain(jsonOp) then
      operation:retain(jsonOp)
    elseif isDelete(jsonOp) then
      operation:delete(jsonOp)
    else
      operation:insert(jsonOp)
    end
  end
  return operation
end

-- Encode a TextOperation as a JSON object. For example, the operation
-- `TextOperation.new():retain(3):insert("Lorem"):delete(5)` is encoded as the
-- JSON object `[3, "Lorem", -5]` (or `{ 3, "Lorem", -5 }` in Lua)
function TextOperation:toJSON()
  return self.ops
end

-- Tests two operations for equality.
function TextOperation.__eq(self, other)
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

-- Skip over a given number of characters.
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

-- Insert a string at the current position.
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

-- Delete a string at the current position.
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

-- How many characters were added by the operations vs. deleted?
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

-- Apply an operation to a string, returning a new string. Throws an error if
-- there's a mismatch between the input string and the operation length.
function TextOperation:__call(doc)
  local parts = {}
  local len = 1

  for i=1, #self.ops do
    local op = self.ops[i]
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

-- Computes the inverse of an operation. The inverse of an operation is the
-- operation that reverts the effects of the operation, e.g. when you have an
-- operation 'insert("hello "); skip(6);' then the inverse is 'delete("hello ");
-- skip(6);'. The inverse should be used for implementing undo.
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

-- Compose merges two consecutive operations into one operation, that
-- preserves the changes of both. Or, in other words, for each input string S
-- and a pair of consecutive operations A and B,
-- apply(apply(S, A), B) = apply(S, compose(A, B)) must hold.
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

-- a .. b is a synonym for a:compose(b).
function TextOperation.__concat(a, b)
  return a:compose(b)
end

-- Transform takes two operations A and B that happened concurrently and
-- returns two operations A' and B' such that
-- apply(apply(S, A), B') = apply(apply(S, B), A'). This function is the heart
-- of OT.
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

-- Export TextOperation
return TextOperation