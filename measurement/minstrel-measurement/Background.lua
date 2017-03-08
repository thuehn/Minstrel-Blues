unistd = require ('posix.unistd')

Background = { cmd = nil
             , args = nil
             , pid = nil
             , parent_pid = nil
             , is_running = nil
             , file = nil
             , buffer = nil 
             }

function Background:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Background:run ( cmd, args )
    local o = Background:new( { cmd = cmd, args = args } )
    o.parent_pid = unistd.getpid()
    local args_str = ""
    for i, arg in ipairs ( args ) do
        if ( i ~= 1 ) then args_str = args_str .. " " end
        args_str = args_str .. arg 
    end
    o.file = io.popen ( cmd .. args_str, "r" )
    return o
end

function Background:wait ()
    repeat
        os.sleep(1)
    until ( self.file )
end

function Background:__tostring() 
    local str = ""
    str = str .. cmd .. " "
    return str
end
