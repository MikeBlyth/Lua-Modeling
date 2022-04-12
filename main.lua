print ('loading main')
require 'utils'
require 'defs'
require 'tests'

-- Init

math.randomseed(os.time())
Secs_per_tick = 10
Clock= Time.string_to_time('8:00')
No_show = 0.1

wr = Waiting_Room:new()
Default_waiting_room = wr

sched = Schedule:new({
    {'8:00','well'}, {'8:00','well'},{'8:15','well'},{'8:15','well'},{'8:30','well'},
    {'8:45','well'},{'9:00','well'},{'9:00','well'},{'9:15','well'},
    {'9:15','well'},{'9:30','well'},{'9:45','well'},{'10:00','well'},
    {'10:00','well'},{'10:30','well'},{'10:45','well'},{'11:00','well'},
    {'11:00','well'}

})

arr = Source:new({name='arrivals'}) -- patients entering the registration queue

--------- RESOURCES --------------------------
Provider = Provider:new({name='Provider'})
provider_pool = Resource_pool:new({type='Provider', count=0})
provider_pool:add(Provider)
ma_pool = Resource_pool:new({type="MA", count=2})
vr_pool = Resource_pool:new({type='vitals_room', count=2})
room_pool = Resource_pool:new({type='exam room', count=4})
reg_clerks = Resource_pool:new({type='Reg Clerk', count=2,} )



------------PROCESSES -----------------
reg = Process:new({name='registration', sources={arr}, required_resources={reg_clerks}})
function reg:post_process()
  local waiting_room = self.waiting_room or Default_waiting_room -- for now only one waiting room, so default to this
  for _, fam in ipairs(self.queue) do
    waiting_room:add(fam)
  end
  self.queue = Queue:new()
end


vitals = Process:new({name='Vitals', sources={wr.Provider},
    required_resources={ma_pool, vr_pool},
    duration_params={type='triangular', min=5, max=20, mode=7}
  })

--[[ 
rep_in_room = Process:new{name='Prep in room', sources={exam}, required_resources={room_pool, ma_pool},
    duration_params={type='triangular', min=0, max=15, mode=5} }

-- ]]
exam = Process:new({name='Provider exam', sources={vitals},
    required_resources={provider_pool, room_pool},
    duration_params={type='triangular', min=5, max=40, mode=10},
  })

post_exam = Branch:new({name='Post-exam', branches={'vax','done'}, sources={exam}, default_branch='done'})
function post_exam:select()
  if math.random() > 0.5 then return('done') else return ('vax') end
end

discharged = Sink:new({name='discharged', sources={post_exam.branches['vax'], post_exam.branches['done']}})
-- d = Sink:new({sources={post_exam}})

for i=1,50 do 
  clk()
end