print ('loading main')
require 'utils'
require 'defs'
require 'model'
require 'tests'


-- Init
function Init()
  math.randomseed(os.time())
  Secs_per_tick = 10
  Clock= Time.string_to_time('8:00')
  No_show = 0.1
  Default_waiting_room = Waiting_Room:new({name='waiting_room'})
end

Init()
---@diagnostic disable-next-line: lowercase-global
m = Model:new({name='test'})


