require 'utils'
require 'tests'



function send_tick(obj, seconds)
  obj.tick(obj,seconds)
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
  Source.mt.__tostring = Source.tostring
  return o
end

function Source:count()
  return self.queue:length()
end

function Source:tick(schedule)
-- Determine whether there are any new patients to insert
  local arrived = schedule:arrived()
  for _, pt in ipairs(arrived) do
    self.destination:add(pt)
    self.created_count = self.created_count + 1
  end
end

function Source:next()
-- return next set of patients (normally a single one)
  return self.queue:remove()
end

function Source:tostring()
  local str = 'Source queue with ' .. self:count() .. ' entries.'
  return str
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
      appt.arrival_time = appt.appt_time + 60*triangular(-10,0,40)
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

Resource = {name='anonymous', type='default', rlock=false}
Resource.mt = {}

function Resource:new(o)
  o = o or {}
  setmetatable(o, Resource.mt)
  Resource.mt.__index = self
  Resource.mt.__tostring = Resource.tostring
  return o
end

function Resource:lock(user)
  if self.rlock then return false end  -- resource already locked, not available
  self.rlock = user or 'locked'
  return self.rlock
end

function Resource:free(user)
  if not (self.rlock and user) then -- user is nil or rlock is (nil or false)
    self.rlock = false
    return true
  end
  if (self.rlock == true) or (self.rlock == 'locked') then
    self.rlock = false
    return true
  end
  error ('Conflict: ' .. user .. ' trying to unlock resource ' .. self.name ..
    ', lock is by ' .. self.rlock ..
    '\nIf lock owner is specified, only that owner or anonymous can unlock ')
end
Resource.unlock = Resource.free


function Resource:tostring()
  local str
  str = self.name .. ' ' .. self.type
  local lock_word
  if self.rlock then lock_word = self.rlock else lock_word = 'available' end
  str = str .. ' (' .. lock_word .. ')'
  return str
end

r = Resource:new({name='Maria', type='MA'})

-- Init

math.randomseed(os.time())
secs_per_tick = 10
clock = Time.string_to_time('8:00')
noshow = 0.1


sched = Schedule:new({
    {'8:00','well'}, {'8:00','well'},{'8:15','well'},{'8:15','well'},{'8:30','well'},
    {'8:45','well'},{'9:00','well'},{'9:00','well'},{'9:15','well'},
    {'9:15','well'},{'9:30','well'},{'9:45','well'},{'10:00','well'},
    {'10:00','well'},{'10:30','well'},{'10:45','well'},{'11:00','well'},
    {'11:00','well'}

})



wr = Source:new() -- waiting room

breaker=0
while clock < Time.string_to_time('12:00') and breaker < 5000 do
  wr:tick(sched)
  clock:advance_sec(secs_per_tick)
  breaker = breaker + 1
end
