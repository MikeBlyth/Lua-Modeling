-- UTILITIES AND DEBUGGING

function dump(o) -- modified
    if o == nil then return 'nil' end
    if type(o) == 'table' then
      local s = '{ '
      if tableIsArray(o) then
        for _, v in ipairs(o) do
          s = s .. dump(v) .. ', '
        end
      else
        for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..']=' .. dump(v) .. ', '
        end
      end
      return s .. '} '
    else
      return tostring(o)
    end
end

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
  for _, _ in ipairs(t) do size = size + 1 end
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
  o.last = table.getn(o)   -- this handles cases where an array is passed
  Queue.mt.__index = self
  Queue.mt.__tostring = Queue.tostring
  return o
end

function Queue:remove ()
  if self.last < self.first then return nil end
  self.first = self.first + 1
  return self[self.first-1]
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

function Queue:tostring()
  local str = '<<'
  for i=self.first, self.last do
    str = str .. tostring(self[i]) .. ', '
  end
  return str .. '>>'
end

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
    local rad = angle * deg2rad
    local sin = math.sin(rad)
    local cos = math.cos(rad)
    local x2 = (cos * v.x) - (sin * v.z)
    local z2 = (sin * v.x) + (cos * v.z)
    return Vector(x2, v.y, z2)
end
