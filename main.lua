require 'utils'

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


function send_tick(obj, seconds)
  obj.tick(obj,seconds)
end

Queue = {first=0, last=-1}
Queue.mt = {}

function Queue:new (o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self.mt)
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

function Queue:length()
    return self.last - self.first + 1
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

Patient = {age=0, visit='well', complexity=1}
Patient.mt = {}
function Patient:new(o)
  o = o or {}
  setmetatable(o, Patient.mt)
  Patient.mt.__index = self
  return o
end

Source = {obj=Patient, rate=5, created_count=0 }
Source.mt = {}

function Source:new(o)
  o = o or {}
  setmetatable(o, Source.mt)
  o.queue = Queue:new()
  o.destination = o.queue  -- will accumulate its own objects by default
  Source.mt.__index = self
  return o
end

--[[
function Source:tick(seconds)
  spawn_per_sec = self.rate/3600
  if math.random() < spawn_per_sec * seconds then
   -- print('New person')
    self.created_count = self.created_count + 1
  end
end
--]]

function Source:tick(schedule)
-- Determine whether there are any new patients to insert
  local arrived = schedule:arrived()
  for _, pt in ipairs(arrived) do
    self.destination:add(pt)
    self.created_count = self.created_count + 1
  end
end

Appointment = {}
Appointment.mt = {}

function Appointment:new(o)
  o = o or {}
  setmetatable(o, Appointment.mt)
  Appointment.mt.__index = self
  Appointment.mt.__tostring = Appointment.tostring
  o.appt_time = Time.string_to_time(o[1])
  o.appt_type = o[2]
  return o
end

function Appointment:tostring()
  local arrival = tostring(self.arrival_time)
  if self.arrival_time > Time.string_to_time('18:00') then arrival = 'no show' end
  return (tostring(self.appt_time) .. ' ' .. self.appt_type .. ' --> ' .. arrival
    .. ' ' .. (self.status or ''))
end

appt = Appointment:new({'8:00','well'})

Schedule = {}
Schedule.mt = {}

function Schedule:new(o)
  o = o or {}
  setmetatable(o, Schedule.mt)
  Schedule.mt.__index = self
  Schedule.mt.__tostring = Schedule.tostring
  local next_id = 0
  for _, appt in ipairs(o) do
    next_id = next_id + 1
    appt.id = next_id
    appt = Appointment:new(appt)
    if math.random() < noshow then
      appt.arrival_time = Time.string_to_time('23:59')
    else
      appt.arrival_time = appt.appt_time + 60*triangular(-10,0,20)
    end
  end
  return o
end

function Schedule:tostring()
  str = ''
  for _, appt in ipairs(self) do
    str = str .. tostring(appt) .. "\n"
  end
  return str
end

function Schedule:arrived()
-- Compare clock with each appointment arrival time
-- Return table of patients who are newly arrived (arrival_time > clock), and
--   mark those appointments as arrived
  local new_arrivals = {}
  new_arrival_count = 0
  for _, appt in ipairs(self) do
    if appt.arrival_time <= clock and appt.status == nil then
      new_arrival_count = new_arrival_count + 1
      new_arrivals[new_arrival_count] = appt
      appt.status = 'arrived'
    end
  end
  return new_arrivals
end

-- Init

math.randomseed(os.time())
secs_per_tick = 10
clock = Time:new({hr=8, min=0, sec=0})
noshow = 0.1

sched = Schedule:new({
    {'8:00','well'}, {'8:00','well'},{'8:15','well'},{'8:15','well'},{'8:30','well'},
    {'8:45','well'},{'9:00','well'},{'9:00','well'},{'9:15','well'},
    {'9:15','well'},{'9:30','well'},{'9:45','well'},{'10:00','well'},
    {'10:00','well'},{'10:30','well'},{'10:45','well'},{'11:00','well'},
    {'11:00','well'}

})

function test_source()

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
end
