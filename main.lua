require 'utils'
require 'tests'



function send_tick(obj, seconds)
  obj.tick(obj,seconds)
end

-------------------- PATIENTS AND FAMILIES -----------------------

Patient = {age=0, visit='well', complexity=1, new=false}
Patient.mt = {}
function Patient:new(o)
  o = o or {}
  setmetatable(o, Patient.mt)
  Patient.mt.__index = self
  return o
end

Family = {}
Family.mt = {}

function Family:new(o)
-- A family is the set of children belonging together (sibs) on a visit
  o = o or {}
  setmetatable(o, Family.mt)
  Family.mt.__index = self
  Family.mt.__tostring = Family.tostring
  return o
end

function Family:tostring()
  s = '{'
  for _,pt in ipairs(self) do
    s = s .. tostring(pt) .. ', '
  end
  return s .. '}'
end

---------- SOURCES -------------------------------

Source = {name='source', obj=Patient, rate=5, created_count=0 }
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

function Source:length()
  return self.queue:length()
end

function Source:tick(schedule)
-- Determine whether there are any new patients to insert
  local arrived = schedule:arrived() -- e.g. {pt1, pt2}
  for _, pt in ipairs(arrived) do
    self.destination:add(Family:new({pt}))   -- put ito the queue
    self.created_count = self.created_count + 1
  end
end

function Source:remove()
-- return next set of patients (normally a single one)
  return self.queue:remove()
end
Source.next = Source.remove

function Source:tostring()
  local str = 'Source "' .. (self.name or '?') .. '" with ' .. self:length() .. ' entries.'
  return str
end

---------- APPOINTMENTS ----------------------------

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
  return ((self.name or '?') .. ' @' ..
    tostring(self.appt_time) .. ' ' .. self.appt_type .. ' --> ' .. arrival
    .. ' ' .. (self.status or ''))
end

--------- SCHEDULES --------------------------

Schedule = {}
Schedule.mt = {}

function Schedule:new(o)
  -- o is an array of appointment slots like
  --sched = Schedule:new({
  --  {'8:00','well'}, {'8:00','well'},{'8:15','well'},{'8:15','well'},{'8:30','well'}}
  o = o or {}
  setmetatable(o, Schedule.mt)
  Schedule.mt.__index = self
  Schedule.mt.__tostring = Schedule.tostring
  local next_id = 0

  -- generate a test schedule by inserting patients  and arrival time ---------------
  for _, appt in ipairs(o) do
    next_id = next_id + 1
    appt.id = next_id
    appt = Appointment:new(appt)
    appt.name = test_names[next_id]
    appt.provider = 'Provider'
    if math.random() < noshow then
      appt.arrival_time = Time.string_to_time('23:59')
    else
      appt.arrival_time = appt.appt_time + 60*triangular(-10,0,40)
    end
  end
  -----------------------------------------------------------------
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

----------- RESOURCES -------------------------------

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

function Resource:unlock(user)
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

function Resource:is_free()
  return not self.rlock
end


function Resource:tostring()
  local str
  str = self.name .. ' ' .. self.type
  local lock_word
  if self.rlock then lock_word = self.rlock else lock_word = 'available' end
  str = str .. ' (' .. lock_word .. ')'
  return str
end
r = Resource:new({name='Maria', type='MA'})

--------- PROCESSES ------------------------------------------------

Process = {name='process', sources={},
    in_process = nil, -- family currently in this process
    status='free',
    duration_params= {type='triangular', min=3, max=15, mode=5},
    finish_time=Time.string_to_time('0:00'),
    post_process = function(p) return end  -- dummy
}
Process.mt = {}


function Process:new(o)
  o = o or {}
  o.required_resources = o.required_resources or {}
  o.current_resources = o.current_resources or {}
  o.queue = Queue:new()  -- for those who have finished process
  setmetatable(o, Process.mt)
  Process.mt.__index = self
  Process.mt.__tostring = Process.tostring
  return o
end

function Process:tick()
  print(self.name .. ' tick')
  if clock < self.finish_time then return end
  -- Time is up; release patients if there are any, mark self as free
  if self.in_process then
    print(self.name .. ' finished')
    self:finish()
  end
  -- Check whether there are any patients waiting for this process
  local source_ready = self:patients_waiting() -- this queue has a patient ready
  print(self.name .. ': source_ready = ' .. tostring(source_ready))
  if source_ready and self:resources_available() then
    self:start_process(source_ready)
  end
end

function Process:start_process(source)  -- source is a Source with a patient ready
  -- Process gets a patient from Queue or other object that has Remove method
  self.in_process = source:remove()  -- this is the family to process
  self:get_resources()
  self.status = 'busy'
  self:set_completion_time(self.duration_params) -- when we'll be done with family
  print('Starting ' .. self.name .. ' with ' .. self.in_process[1].name .. ' until '
   .. tostring(self.finish_time))
end

function Process:set_completion_time(params)
  -- can override with custom function
  local duration
  if params.type=='triangular' and params.min and params.max and params.mode then
    duration = triangular(params.min, params.max, params.mode) -- duration in min
  end
  if params.type=='uniform' and params.min and params.max then
    duration = params.min + math.random()*(params.max-params.min)
  end
  if type(params[1]) == 'number' then  -- can simply use a fixed number of minutes
    duration = params[1]
  end
  if not duration then
    error('Invalid duration specs for process' .. self.name)
  end
  self.finish_time = clock + Time:new({min=duration})
end
--]]


function Process:patients_waiting()
  for _,source in ipairs(self.sources) do
    if source:length() > 0 then return source end
  end
  return false
end

function Process:resources_available()
  for _, pool in ipairs(self.required_resources) do
    if pool:free_count() == 0 then
      return false
    end
  end
  return true
end

function Process:get_resources()
  if not self:resources_available() then return nil end
  for _, pool in ipairs(self.required_resources) do
    -- obtain resource from pool
    local res = pool:request()
    table.insert(self.current_resources, res)
  end
  return true
end

function Process:finish()
  if self.in_process then
    self:move_to_finished()
  end
  self.in_process = nil
  -- release Resources
  for _,res in ipairs(self.current_resources) do
    res:unlock()
  end
  self.current_resources = {}
  self.status='free'
  self:post_process(finished_fam)
end

function Process:move_to_finished()
  local finished_fam = self.in_process
  self.queue:add(self.in_process) -- move current patient to finished queue
end

function Process:tostring()
  s = 'Process: "' .. self.name .. '"'
  if self.status == 'free' then
    s = s .. ' (free).'
  else
    s = s .. ', with ' .. tostring(self.in_process) .. ' until ' .. tostring(self.finish_time) .. '.'
  end
  s = s .. '\nFinished queue has ' .. self.queue:length() .. ' entries.'
  local in_use = 'Resources in use: '
  for _, res in ipairs(self.current_resources) do
    in_use = in_use .. tostring(res) .. ', '
  end
  if in_use > '' then s = s .. '\n' .. in_use end
  return s
end


-- Functions to make Processes act like source queues, using their internal 'queue' (patients finished with the process)

function Process:length()
  return self.queue:length()
end

function Process:remove()
  return self.queue:remove()
end

-------- BRANCHES --------------------------------------

Branch = Process:new({name=process, duration_params={type='fixed', 0}})
Branch.mt = {}

function Branch:new(o)
  -- A Branch is a special process that simply takes a patient from its source and
  -- moves it into one of several output (finished) queues. Functions as a choice point.
  -- For example, used to route some patients into getting vaccines after their exam,
  -- while others are finished their visit.
  -- To use, just (1) create the Branch like
  -- post_exam = Branch:new({name='Post-exam', branches={'vax','done'}, sources={exam}, [default_branch='done']})
  -- (2) create a select() function which will return the name of the branch to be assigned for this patient, e.g.
  --  function post_exam:select()
  --    if math.random() > 0.1 then return('done') else return ('vax') end
  --  end

  o = o or {}
  local branches = o.branches
  o.branches = {}
  o.queue = nil  -- branches rather than queue is used in a Branch
  setmetatable(o, Branch.mt)
  Branch.mt.__index = self
  Branch.mt.__tostring = Branch.tostring
  for _,branch in ipairs(branches) do
    o.branches[branch] = Queue:new()  -- create destination queue with key=branch
  end
  return o
end

function Branch:move_to_finished()
  -- same as Process:move_to_finished but puts finished patient in one of the branches.
  local finished_fam = self.in_process
  self.branches[self:select()]:add(self.in_process) -- move to default finished queue
end

function Branch:select()
  if self.default_branch == nil then
    error('Branch ' .. self.name .. ' has no default branch or select function.')
  end
  return self.default_branch
end

function Branch:tostring()
  s = 'Branch ' .. self.name .. ': '
  for br,queue in pairs(self.branches) do
    s = s .. br .. '=' .. queue:length() .. ', '
  end
  return s
end



---- PROVIDERS -----------------------------------------

Provider = Resource:new({type='Provider', name='Provider'})
Provider.mt = {}

function Provider:new(o)
  o = o or {}
  o.waiting_room = o.waiting_room or default_waiting_room
  setmetatable(o, Provider.mt)
  Provider.mt.__index = self
  Provider.mt.__tostring = Provider.tostring
  if o.waiting_room[o.name] then   -- already defined name -- make a variation
    local suffix = 2
    while o.waiting_room[o.name] do
      o.name = o.name .. '_' .. suffix
      suffix = suffix + 1
    end
  end
  o.waiting_room[o.name] = Queue:new()
  return o
end

function Provider:tostring()
  return self.name .. '*'
end


Queue_for_Provider = {name='ProviderName'}
Queue_for_Provider.mt = {}

function Queue_for_Provider:new(o)
  o = o or {}
  setmetatable(o, Queue_for_Provider.mt)
  Queue_for_Provider.mt.__index = self
  Queue_for_Provider.mt.__tostring = Queue_for_Provider.tostring
  o.queue = Queue:new()
  return o
end

------------- WAITING ROOM -----------------------

Waiting_Room = {}
Waiting_Room.mt = {}

function Waiting_Room:new(o)
  o = o or {}
  setmetatable(o, Waiting_Room.mt)
  Waiting_Room.mt.__index = self
  Waiting_Room.mt.__tostring = Waiting_Room.tostring
  return o
end

function Waiting_Room:add(fam) -- add a family to a provider queue in waiting room
  local provider = fam[1].provider  -- use first/only pt since all have same provider
  wr[provider] = wr[provider] or Queue:new()  -- make new queue if needed
  wr[provider]:add(fam)
end

function Waiting_Room:length()
  local n = 0
  for _, provider in pairs(self) do
    if provider.mt == Queue.mt then
      n = n + provider:length()
    end
  end
  return n
end

function Waiting_Room:tostring()
  return "Waiting room: " .. self:length() .. ' patients'
end
--------- RESOURCE POOL ----------------------

Resource_pool = {type=nil, count=0}
Resource_pool.mt = {}

function Resource_pool:new(o)
  o = o or {}
  o.members = o.members or {}
  setmetatable(o, Resource_pool.mt)
  Resource_pool.mt.__index = self
  Resource_pool.mt.__tostring = Resource_pool.tostring
  if (o.type and o.count) and o.count > 0 then
    for i=1, o.count do
      local name = o.type .. '_' .. i
      o.members[i] = Resource:new({name=name, type=o.type})
    end
  end
  return o
end

function Resource_pool:free_count()
  local free = 0
  for _, member in ipairs(self.members) do
    if member:is_free() then free = free + 1 end
  end
  return free
end

function Resource_pool:request()
  local free_members = {}
  local fi = 0
  local selected = nil
  for _, member in ipairs(self.members) do
    if member:is_free() then
      fi = fi + 1
      free_members[fi] = member
    end
  end
  if fi > 0 then
    selected = free_members[math.random(fi)]
    selected:lock()
  end
  return selected
end

function Resource_pool:add(r)
  if arrayContains(self.members,r) then
    error ('Trying to add duplicate resource ' .. r .. ' to resource pool ' ..
      self.name)
  end
  if r==nil then
    error ('Trying to add nil value to resource pool ' .. self.type)
  end
  table.insert(self.members, r)
  self.count = self.count + 1
end

function Resource_pool:tostring()
  s = 'Resource pool: ' .. 'type=' .. self.type .. ', count=' .. self.count ..
    ', free=' .. self:free_count()
  s = s .. '\n'
  for i,res in ipairs(self.members) do
    s = s .. tostring(res) .. ','
  end
  return s
end


-- Init

math.randomseed(os.time())
secs_per_tick = 10
clock = Time.string_to_time('8:00')
noshow = 0.1

wr = Waiting_Room:new()
default_waiting_room = wr

sched = Schedule:new({
    {'8:00','well'}, {'8:00','well'},{'8:15','well'},{'8:15','well'},{'8:30','well'},
    {'8:45','well'},{'9:00','well'},{'9:00','well'},{'9:15','well'},
    {'9:15','well'},{'9:30','well'},{'9:45','well'},{'10:00','well'},
    {'10:00','well'},{'10:30','well'},{'10:45','well'},{'11:00','well'},
    {'11:00','well'}

})

arr = Source:new({name='arrivals'}) -- patients entering the registration queue

-- Registration desk (haven't set up yet to require resources -- assume available)
reg = Process:new({name='registration', sources={arr}})
function reg:post_process(fam, waiting_room)
  waiting_room = waiting_room or wr -- for now only one waiting room, so default to this
  for _, f in ipairs(self.queue) do
    waiting_room:add(f)
  end
  self.queue = Queue:new()
end

Provider = Provider:new({name='Provider'})
provider_pool = Resource_pool:new({type='Provider', count=0})
provider_pool:add(Provider)
ma_pool = Resource_pool:new({type="MA", count=2})
vr_pool = Resource_pool:new({type='vitals_room', count=2})
room_pool = Resource_pool:new({type='exam room', count=4})


function Process:get_resources()
  success = true
  for _, pool in ipairs(self.required_resources) do
    if pool:free_count() == 0 then
      return false
    end
  end
  for _, pool in ipairs(self.required_resources) do
    -- obtain resource from pool
    local res = pool:request()
    table.insert(self.current_resources, res)
  end
  return true
end

vitals = Process:new({name='Vitals', sources={wr.Provider},
    required_resources={ma_pool, vr_pool},
    duration_params={type='triangular', min=5, max=20, mode=7}
  })

exam = Process:new({name='Provider exam', sources={vitals},
    required_resources={provider_pool, room_pool},
    duration_params={type='triangular', min=5, max=40, mode=10},
  })

post_exam = Branch:new({name='Post-exam', branches={'vax','done'}, sources={exam}, default_branch='done'})
function post_exam:select()
  if math.random() > 0.5 then return('done') else return ('vax') end
end
