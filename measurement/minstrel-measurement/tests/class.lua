local posix = require 'posix'

Class = { time = nil } -- don't initialize the prototype respectivly initialize class globals here
function Class:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Class:create ( time )
    local o = Class:new({ time = time })
    return o
end

function Class:__tostring() 
    return self.time
end

function Class:update ()
    self.time = os.time()
end 

local a = Class:create("now")
local b = Class:create("now")

assert ( a.time == "now" )
assert ( b.time == "now" )

a:update()
posix.sleep(1)
b:update()

assert ( a.time ~= b.time )
