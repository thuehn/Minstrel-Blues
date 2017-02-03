-- module LogNode: This module is indented to be a
-- base implementation of a message logging service
-- for use in combination with RPC for network wide access
--
-- This module just markup messages with a message type
-- like INFO, WARNING or ERROR and the system time
-- when the message was received
--
-- The complete message strings are stored in
-- a file and printed to standard out
--
-- For a runnable logging node see file Logger.lua
-- 
-- TOOD: what happens when lots of nodes try to connect
-- the logger at the same time? do they wait for connection
-- (connection timed out) or does the logging node accept
-- the connections sequentially (connection refused)

-- prototype table
LogNode = { name = nil, fname = nil, logfile = nil }

-- create an object table with LogNode prototype
-- and optional initializer table
-- param o: initializer table, i.e. {name = "Logger", fname = "/tmp/lua.log"} (maybe nil)
function LogNode:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- create a LogNode object from initial values
-- and open the log file in append mode
-- param name: a name for the logging node
-- param fname: the name of the log file
function LogNode:create( name, fname )
    o = LogNode:new({ name = name, fname = fname })
    o.logfile = io.open ( fname, "a")
    return o
end

-- convert LogNode object to string
function LogNode:__tostring() 
    return self.name .. " :: " 
            .. "log file name = " .. self.fname .. ", "
            .. "open = " .. tostring(self.logfile ~= nil) 
end

-- base message passing function
-- param msgtype: "INFO", "WARNING", "ERROR"
-- param from: name of the sender
-- param msg: the message string to pass to logger
function LogNode:send ( msgtype, from, msg )
    local ret = os.time() .. " " .. msgtype .. " : " .. from .. " : " .. msg
    print ( ret )
    if not self.logfile then 
        print ("error: logfile closed"); 
        return nil 
    end
    self.logfile:write ( ret .. '\n')
    self.logfile:flush()
end

function LogNode:set_cut()
    local cut = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    print ( cut )
    if not self.logfile then 
        print ("error: logfile closed"); 
        return nil 
    end
    self.logfile:write ( cut .. '\n')
    self.logfile:flush()
end

-- shortcut function for passing an info tagged message
function LogNode:send_info( from, msg )
    self:send( "INFO", from, msg )
end

-- sshortcut function for passing a waring tagged message
function LogNode:send_warning( from, msg )
    self:send( "WARNING", from, msg )
end

-- shortcut function for passing an error tagged message
function LogNode:send_error( from, msg )
    self:send( "ERROR", from, msg )
end
