Model = {}
function Model:new(o)
    o = o or {}
    setmetatable(o, self)
    Model.__index = self
    Model.tostring = function(m) return 'Model=' .. (m.name or '?') end
    Model.__tostring = Model.tostring
    o.wr = Default_waiting_room
  
    o.sched = Schedule:new({
        {'8:00','well'}, {'8:00','well'},{'8:15','well'},{'8:15','well'},{'8:30','well'},
        {'8:45','well'},{'9:00','well'},{'9:00','well'},{'9:15','well'},
        {'9:15','well'},{'9:30','well'},{'9:45','well'},{'10:00','well'},
        {'10:00','well'},{'10:30','well'},{'10:45','well'},{'11:00','well'},
        {'11:00','well'}
  
    })
  
    o.arr = Source:new({name='arrivals'}) -- patients entering the registration queue
  
    --------- RESOURCES --------------------------
    -- Provider = Provider:new({name='Provider'})
    o.provider_pool = Resource_pool:new({type='Provider', count=1})
    o.ma_pool = Resource_pool:new({type="MA", count=2})
    o.vr_pool = Resource_pool:new({type='vitals_room', count=2})
    o.room_pool = Resource_pool:new({type='exam room', count=4})
    o.reg_clerks = Resource_pool:new({type='Reg Clerk', count=2,} )
   
    ------------PROCESSES -----------------
    o.reg = Process:new({name='registration', sources={o.arr}, required_resources={o.reg_clerks}, wr=o.wr})
    function o.reg:post_process() -- Move processed fams into waiting room queue for provider
      local fam = self.queue:remove()
      while fam do
        self.wr:add(fam)
        fam = self.queue:remove()
      end
    end
  
    o.vitals = Process:new({name='Vitals', sources={o.wr.Provider},
        required_resources={o.ma_pool, o.vr_pool},
        duration_params={type='triangular', min=5, max=20, mode=7}
      })
  
    --[[ 
    rep_in_room = Process:new{name='Prep in room', sources={exam}, required_resources={room_pool, ma_pool},
        duration_params={type='triangular', min=0, max=15, mode=5} }
  
    -- ]]
    o.exam = Process:new({name='Provider exam', sources={o.vitals},
        required_resources={o.provider_pool, o.room_pool},
        duration_params={type='triangular', min=5, max=40, mode=10},
      })
  
    o.post_exam = Branch:new({name='Post-exam', branches={'vax','done'}, sources={o.exam}, default_branch='done'})
    function o.post_exam:select()
      if math.random() > 0.5 then return('done') else return ('vax') end
    end
  
    o.discharged = Sink:new({name='discharged', sources={o.post_exam.branches['vax'], o.post_exam.branches['done']}})
  -- List of processes to receive time tick messages. ORDER MATTERS
  o.tick_targets = {o.arr, o.reg, o.vitals, o.exam, o.post_exam, o.discharge}
  return o
end

function Model:finished()
  return self.discharged:length() == self.sched:count()
end  

function Model:ticker()
  Clock:advance_min(5)
  for _,target in ipairs(self.tick_targets) do
    target:tick(self.sched)
  end
  self:report()
end

function Model:report()
  print(Clock)
  print(self.sched)
  print(self.arr)
  print(self.reg)
  print(self.wr)
  print(self.vitals)
  print(self.exam)
  print(self.post_exam)
  print(self.discharged)
end