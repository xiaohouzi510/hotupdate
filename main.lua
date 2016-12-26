local hotupdate = require "hotupdate"
local test 	    = require "base.test"
test.init()

function sleep(t)
  local now_time = os.clock()
  while true do
    if os.clock() - now_time > t then
      hotupdate.update_file("base.test")
      return
    end
  end
end

test.func()
hotupdate.update_file("base.test")
test.func()
while true do
  test.func()
  if test.hello then
  	test.hello()
  end
  sleep(3)
end
