a=1

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

function send_tick(obj, seconds)
  obj.tick(obj,seconds)
end

Queue = {first=0, last=-1}
function Queue:new (o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self)
  Queue.mt.__index = self
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
Patient.mt = {}
function Patient:new(o)
  o = o or {}
  setmetatable(o, Patient.mt)
  Patient.mt.__index = self
  return o
end

Source = {obj=Patient, rate=5, objects={}, created_count=0 }
Source.mt = {}

function Source:new(o)
  o = o or {}
  setmetatable(o, Source.mt)
  o.destination = o.objects  -- will accumulate its own objects by default
  Source.mt.__index = self
  return o
end

function Source:tick(seconds)
  spawn_per_sec = self.rate/3600
  if math.random() < spawn_per_sec * seconds then
   -- print('New person')
    self.created_count = self.created_count + 1
  end
end

-- Init

math.randomseed(os.time())
secs_per_tick = 10
clock = Time:new({hr=8, min=0, sec=0})


wr = Source:new()

end_time = Time:new({hr=9})
created = {}
total_created = 0
test_runs = 1000
test_rate = 5
wr.rate = test_rate
for i=1,test_runs do
  n = 0    -- to escape endless loops
  clock = Time:new({hr=8, min=0, sec=0})
  while clock <= end_time do
  -- if (clock.raw % 600) == 0 then print(clock:tostring()) end
    send_tick(wr, secs_per_tick)
    clock = clock + {sec=secs_per_tick}
    n = n + 1
    if n > 1000 then break
    end
  end
  -- print ("created " .. wr.created_count .. " patients.")
  created[wr.created_count] = (created[wr.created_count] or 0) + 1
  total_created = total_created + wr.created_count
  wr.created_count = 0
end
for i = 1,10 do print(i, created[i] or 0) end
print ("Average per run = ", total_created/test_runs .. " error = " .. test_rate*test_runs/total_created)
