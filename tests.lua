print ('loading tests')

function test_source()
-- used mainly to check random arrival of patients
  wr = Source:new()

  end_time = Time:new({hr=9})
  created = {}
  total_created = 0
  test_runs = 1000
  test_rate = 5
  wr.rate = test_rate
  for i=1,test_runs do
    local n = 0    -- to escape endless loops
    Clock = Time:new({hr=8, min=0, sec=0})
    while Clock <= end_time do
    -- if (Clock.raw % 600) == 0 then print(Clock:tostring()) end
      send_tick(wr, Secs_per_tick)
      Clock = Clock:advance_sec(Secs_per_tick)
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

--[[
function Source:tick(seconds)
-- random arrival in Poisson distribution at rate patients/hr
spawn_per_sec = self.rate/3600
  if math.random() < spawn_per_sec * seconds then
   -- print('New person')
    self.created_count = self.created_count + 1
  end
end
--]]


function clk()
  clocker(5)
  arr:tick(sched)
  reg:tick()
  vitals:tick()
  exam:tick()
  post_exam:tick()
  discharged:tick()
  print(Clock)
  print(sched)
  print(arr)
  print(reg)
  print(wr)
  print(vitals)
  print(exam)
  print(post_exam)
  print(discharged)
  pe = post_exam
end


function clocker(n)
  Clock:advance_min(n)
end
