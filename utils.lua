---@diagnostic disable: lowercase-global
-- UTILITIES AND DEBUGGING
print ('loading utils')
function dump(o) -- modified
    if o == nil then return 'nil' end
    if type(o) == 'table' then
      local s = '{ '
      if tableIsArray(o) then
        for _, v in ipairs(o) do
          if v == o then 
            -- trying to dump self will be an infinite loop!
          s = s .. tostring(v) .. ',' -- like when self.__index = self
          else
            s = s .. dump(v) .. ', '
        end
        end
      else
        for k,v in pairs(o) do
          if type(k) == 'table' then 
          k = dump(k) 
          else
            if type(k) ~= 'number' then k = '"'..k..'"' end
          end
          if v == o then 
            -- trying to dump self will be an infinite loop!
            s = s .. '['..k..']=' .. tostring(v) .. ',' -- like when self.__index = self
          else
            s = s .. '['..k..']=' .. dump(v) .. ', '
          end
        end
      end
      if getmetatable(o) then s = s .. '**metatable=' .. tostring(getmetatable(o)) end 
      return s .. '} '
    else
      return tostring(o)
    end
end


--[[ Probably superfluous since entries in mt.__index won't show up in pairs()
function rawdump(o) -- dump a table IGNORING its inherited elements (from mt.__index)
  if (type(o) ~= 'table') then return dump(o) end
  local mt = getmetatable(o)
  if mt==nil or mt.__index == nil then return dump(o) end
  local save_index = mt.__index
  local results = dump(o)
  mt.__index = save_index
  return results
end
--]]


function pdump(o, s)
    s = s or ''
    print(s .. ': ' .. dump(o))
end

function tableIsArray(t) -- quick check, see if indices are sequential
  local i = 1
  for k, _ in pairs(t) do
    if k ~= i then return false end
    i = i + 1
  end
  return true
end

function firstWord(s)
    return string.match(s, ('%a+'))
end

function arrayContains(array, value)  -- check if array contains value -- DOESN'T WORK WITH ASSOCIATIVE TABLES!
    for i, v in ipairs(array) do
        if v == value then return i end
    end
    return nil
end

function copyTable(t) --
--- just enough to suit my needs, not a general utility!
  if t == nil then return nil end
  if not type(t) == 'table' then return end
  local new = {}
  for k, v in pairs(t) do
    v2 = v
    if type(v) == 'table' then
        v2 = copyTable(v)
    end
    new[k] = v2
  end
  return new
end

function mergeTables(params, newParams)
-- update params with newParams, return new table
    local t = copyTable(params) or {}
    if newParams then
        for k, v in pairs(newParams) do
            t[k] = v
        end
    end
    return t
end

function arrayRemove(array, value)  --  DOESN'T WORK WITH ASSOCIATIVE TABLES! (Just use array.value = nil)
    local newArray = {}
    for i, v in ipairs(array) do
        if v ~= value then
            table.insert(newArray,v)
        end
    end
    return newArray
end

function tableSize(t)
  local size = 0
  for _, _ in pairs(t) do size = size + 1 end
  return size
end

function debugPrint(switch, table)
    assert(type(table) == 'table', "Debug print takes switch and table!")
--    print ('debug print, sw=', switch, ': ', debug.switch)
    if debug[switch] then
        for i,v in ipairs(table) do
            print(v)
        end
    end
end

function printDelim(vals, delim )
    local delim = delim or ', '
    s = ''
    for i, v in ipairs(vals) do
        if i ~= 1 then s = s .. delim end
        s = s .. tostring(v)
    end
    print(s)
end

Time = {hr=0, min=0, sec=0, raw=0}
Time.mt = {}

function Time:new(o)
  o = o or {}
  setmetatable(o, Time.mt)
  Time.mt.__index = self
  Time.mt.__tostring = Time.tostring
  if o.raw == 0 then
    o:set_raw()
  else
    o:set_hms()
  end
  return o
end

function Time:set_raw()
  self.raw = (self.hr or 0)*3600 + (self.min or 0)*60 + (self.sec or 0)
end

function Time:set_hms()
  self.hr = math.floor(self.raw/3600)
  self.min = math.floor((self.raw % 3600)/60)
  self.sec = self.raw % 60
end

function Time:tostring()
  return  string.format("%d:%02d:%02d", self.hr, self.min, self.sec)
end

function Time.get_raw(t)
  -- t can be any table
  if t.raw then
    return t.raw
  else
    return (t.hr or 0)*3600 + (t.min or 0)*60 + (t.sec or 0)
  end
end

function Time.add(a,b)
  if getmetatable(a) ~= Time.mt then
    error('Time.add requires Time object as first argument')
  end
  local result
  if type(b) == 'number' then
    result = Time:new({raw=a.raw + b})
  else
    result = Time:new({raw=a.raw+Time.get_raw(b)})
  end
  return result
end

function Time:advance_min(min)
  if getmetatable(self) ~= Time.mt then
    error('Time.add requires Time object as first argument')
  end
  self.raw = self.raw + min*60
  self:set_hms()
  self.check = 'OK'
end

function Time:advance_sec(sec)
  if getmetatable(self) ~= Time.mt then
    error('Time.add requires Time object as first argument')
  end
  self.raw = self.raw + sec
  self:set_hms()
  self.check = 'OK'
end

function Time.mt.__lt (a, b)
  if not (a.raw and b.raw) then
    error('Time comparison error - raw not defined for both objects')
  end
  return a.raw < b.raw
end
function Time.mt.__le (a, b)
  if not (a.raw and b.raw) then
    error('Time comparison error - raw not defined for both objects')
  end
  return a.raw <= b.raw
end
function Time.mt.__gt (a, b)
  if not (a.raw and b.raw) then
    error('Time comparison error - raw not defined for both objects')
  end
  return a.raw > b.raw
end
function Time.mt.__ge (a, b)
  if not (a.raw and b.raw) then
    error('Time comparison error - raw not defined for both objects')
  end
  return a.raw >= b.raw
end
function Time.mt.__eq (a, b)
  if not (a.raw and b.raw) then
    error('Time comparison error - raw not defined for both objects')
  end
  return a.raw == b.raw
end
function Time.mt.__ne (a, b)
  if not (a.raw and b.raw) then
    error('Time comparison error - raw not defined for both objects')
  end
  return a.raw ~= b.raw
end
Time.mt.__add = Time.add

function Time.string_to_time(s)
  local hr, min, sec
  _, _, hr, min, sec = string.find(s,"([0-9][0-9]?):([0-9][0-9]):?(%d*)")
  if hr == nil then error('Trying to convert invalid time literal ' .. s) end
  if (sec==nil) or (sec=='') then sec='0' end
  return Time:new({hr=hr, min=min, sec = sec})
end

Queue = {first=1, last=0}
Queue.mt = {}

function Queue:new (o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self.mt)
---@diagnostic disable-next-line: undefined-field
  o.last = table.getn(o)   -- this handles cases where an array is passed
  Queue.mt.__index = self
  Queue.mt.__tostring = Queue.tostring
  return o
end

function Queue:remove ()
  if self.last < self.first then return nil end
  local removed = self[self.first]
  self[self.first]=nil
  self.first = self.first + 1
  return removed
end

function Queue:add (item)
    self.last = self.last + 1
    self[self.last] = item
end

function Queue:peek_next()  -- just return next in line but don't remove from queue
  if self.last < self.first then return nil end
  return self[self.first]
end
Queue.peek_first = Queue.peek_next

function Queue:peek_last()
  if self.last < self.first then return nil end
  return self[self.last]
end

function Queue:length()
    return self.last - self.first + 1
end

function Queue:empty()
    return self.last < self.first
end

function Queue:truncate()  -- but this doesn't clear garbage!
  self.first=0
  self.last=1
end

function Queue:tostring()
  local str = '<<'
  for i=self.first, self.last do
    str = str .. tostring(self[i]) .. ', '
  end
  return str .. '>>'
end

---------- QUEUE COLLECTION

Queue_collection = {name='Qc'}

function Queue_collection:new(o)
  print('qc new')
  o = o or {}
  self.__index = self
  self.__tostring = self.tostring
  setmetatable(o, self)
  return o
end 

function Queue_collection:add(key,item)
  self[key] = self[key] or Queue:new()
  self[key]:add(item)
end

function Queue_collection:remove(key)
  return self[key]:remove()
end

function Queue_collection:length(key)
  return self[key]:length() or 0
end

function Queue_collection:empty(key)
  return self[key]:empty()
end

function Queue_collection:tostring()
  s = ''
  for k, q in pairs(self) do
    local qstr
    if q == self then 
      qstr = '*self*'
    else
      qstr = tostring(q)
    end  
    s = s .. tostring(k) .. '->' .. qstr .. '\n'
  end
  return s
end

function Queue_collection:dump()  -- uses Symtab if available
  local smt = getmetatable(self)
  local s = (self.name or '?') .. ": mt=" .. Symtab.get(smt) .. '; tostring=' .. Symtab.get(self.tostring) .. '; __tostring=' .. Symtab.get(self.__tostring) 
  if smt then 
    s = s .. '; mt.__index=' .. Symtab.get(smt.__index)
    s = s ..  '; mt.__tostring=' .. Symtab.get(smt.__tostring) .. '\n'
  end
  print(s)
end

------ Symbol Table
Symtab = {}
function Symtab.add(obj, name)
  local raw = rawstr(obj)
  local tf, key, addr
  _, _, key, addr = string.find(raw, "(%a+):%s*(.+)")
  name = name or obj.name or '?'
  Symtab[raw] = name .. ' (' .. string.sub(key, 1,1) .. ')'
end
function Symtab.get(obj) -- get name from object or address string
  local addr
  if obj == nil then return 'nil' end
  if type(obj) ~= 'string' then -- i.e. argument is the object itself
    addr = rawstr(obj)
  else
    addr = obj   -- argument is like 'table: 0x1512d50'
  end
  return Symtab[addr] or addr
end

---- rawstr - returns tostring of object itself without its mt.__tostring
function rawstr(t)
  local mt = getmetatable(t)
  local save_tostring
  if mt and mt.__tostring then
     save_tostring = mt.__tostring
     mt.__tostring = nil
  end
  local raw = tostring(t)
  if save_tostring then
    mt.__tostring = save_tostring
  end
  return raw
end

--------- OTHER -----------

function triangular(a, b, c)
-- a = low limit, b = high limit, c = mode
-- see https://bit.ly/3tVdfHD in Wikipedia
  local u = math.random()
  local inflex = (c-a)/(b-a)
  if u < inflex then
    return a + math.sqrt(u*(b-a)*(c-a))
  else
    return b - math.sqrt((1-u)*(b-a)*(b-c))
  end
end

function is_instance_of(a,b)
  return getmetatable(a) == getmetatable(b) or getmetatable(a) == b
end

----------======== VECTORS ========-------------

function rotate(v, angle)  -- 2d rotation of standard TTS position vector
    local rad = angle * math.pi/180
    local sin = math.sin(rad)
    local cos = math.cos(rad)
    local x2 = (cos * v.x) - (sin * v.z)
    local z2 = (sin * v.x) + (cos * v.z)
    return Vector(x2, v.y, z2)
end

