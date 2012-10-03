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

function TextOperation.new(ops)
  return setmetatable({ ops = ops or {} }, TextOperation)
end

setmetatable(TextOperation, {
  __call = function(_, ...)
    return TextOperation.new(...)
  end
})

function TextOperation:retain(n)
  ops = self.ops
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
  ops = self.ops
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
  ops = self.ops
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

function TextOperation:__call(doc)
  local parts = {}
  local len = 1

  for i=1, #self.ops do
    op = self.ops[i]
    if isRetain(op) then
      if len + op > #doc + 1 then
        error("Cannot apply operation: operation is too long")
      end
      table.insert(parts, string.sub(doc, len, len + op))
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

return TextOperation