---@diagnostic disable: lowercase-global
--t = Set:new({'cat', 'dog'})
--u = Set:new({'cat', 'lion'})
--v = t+u => {'cat', 'dog', 'lion'),  set UNION, not adding an element!
--v = t-u => {'cat'}. set INTERSECTION, not removing element or all elements in u!
--f = {type='family', n=2}
--w = Set:new({'cat', 5, f}) => {5, cat, table: 0x123ddd0}
--w:add('dog') => {5, dog, cat, table: 0x123ddd0}. CHANGES TABLE, does not return new table
--w:remove(f) => {5, dog, cat}. CHANGES TABLE, does not return new table

Set = {}

function Set:new (t)
  local o = {}
  t = t or {}
  setmetatable(o, self)
  Set.__index = self
  Set.__tostring = Set.tostring
  for _, l in ipairs(t) do o[l] = true end
  return o
end

function Set.union (a,b)
  local res = Set:new{}
  for k in pairs(a) do res[k] = true end
  for k in pairs(b) do res[k] = true end
  return res
end

function Set.intersection (a,b)
  local res = Set:new{}
  for k in pairs(a) do
    res[k] = b[k]
  end
  return res
end

function Set:add(value)
  self[value] = true
  return self
end

function Set:remove(value)
  self[value] = nil
  return self
end

function Set.tostring (set)
  local s = "{"
  local sep = ""
  for e in pairs(set) do
    s = s .. tostring(sep) .. tostring(e)
    sep = ", "
  end
  return s .. "}"
end

Set.__add = Set.union
Set.__sub = Set.intersection

do
  local t,u,v,f,w
  t = Set:new({'cat', 'dog'})
  u = Set:new({'cat', 'lion'})
  v = t+u
  print (v, ' should be {cat, dog, lion}')
  f = {type='family', n=2}
  w = Set:new({'cat', 5, f})
  print (w)
  w:add('dog')
  print(w)
  w:remove(f)
  print (w)
end