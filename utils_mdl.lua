
Time = {hr=0, min=0, sec=0, raw=0}
Time.mt = {}

function Time:new(o)
  o = o or {}
  setmetatable(o, Time.mt)
  Time.mt.__index = self
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

Time.mt.__add = Time.add


t = Time:new({hr=12, min=15, sec=0})
print (t:tostring(), t.raw)
u = Time:new({hr=0, min=20, sec=0})
print (u:tostring(), u.raw)
v = Time.add(t,u)
print ("t+u=", v:tostring())


Queue = {first=0, last=-1}
function Queue:new (o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self)
  Queue.__index = self
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

function Queue:length()
    return self.last - self.first + 1
end

function triangular(a, b, c)
-- a = low limit, b = high limit, c = mode
-- see https://bit.ly/3tVdfHD in Wikipedia
  local u = math.random()
  local inflex = (c-a)/(b-a)
  print (u, inflex)
  if u < inflex then
    return a + math.sqrt(u*(b-a)*(c-a))
  else
    return b - math.sqrt((1-u)*(b-a)*(b-c))
  end
end

Patient = {age=0, visit='well', complexity=1}

Source = {obj=Patient, }
