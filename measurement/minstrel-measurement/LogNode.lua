
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
-- For a runnable logging node see file bin/runLogger.lua
-- 
-- TOOD: what happens when lots of nodes try to connect
-- the logger at the same time? do they wait for connection
-- (connection timed out) or does the logging node accept
-- the connections sequentially (connection refused)

net = require ('Net')

-- prototype table
LogNode = { name = nil
          , fname = nil
          , logfile = nil
          , use_stdout = nil
          , append_mode = nil
          }

-- create an object table with LogNode prototype
-- and optional initializer table
-- param o: initializer table, i.e. {name = "Logger", fname = "/tmp/lua.log"} (maybe nil)
function LogNode:new (o)
    local o = o or {}
    setmetatable ( o, self )
    self.__index = self
    return o
end

-- create a LogNode object from initial values
-- and open the log file in append mode
-- param name: a name for the logging node
-- param fname: the name of the log file
function LogNode:create( name, fname, use_stdout, append_mode )
    local o = LogNode:new( { name = name
                           , fname = fname
                           , use_stdout = use_stdout
                           , append_mode = append_mode
                           } )
    local mode = "w"
    if ( append_mode == true ) then
        mode = "a"
    end
    o.logfile = io.open ( fname, mode)
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
    local prefix = os.time () .. " " .. msgtype .. " : " .. from .. " : "
    local lines = ""
    if ( string.len ( msg ) >= 80 ) then
        local msg_noindent
        if ( string.find ( msg, "\n" ) == nil ) then
            msg_noindent = ( msg ):gsub ( ("."):rep ( 80 ),"%1\n" ):sub ( 1, -1 )
        else
            msg_noindent = msg
        end
        local tab = string.rep (" ", string.len ( prefix ) )
        for i, part in ipairs ( split ( msg_noindent, "\n" ) ) do
            if ( i > 1 ) then
                lines = lines .. tab
            end
            lines = lines .. part .. "\n"
        end
    else
        lines = msg
    end
    local ret = prefix .. ( lines or "" )
    if ( self.use_stdout == true ) then
        print ( ret )
    end
    if not self.logfile then 
        print ("error: logfile closed"); 
        return nil 
    end
    self.logfile:write ( ret .. '\n')
    self.logfile:flush()
end

function LogNode:set_cut()
    local cut = ""
    for i=1, 80 do
        cut = cut .. '~'
    end
    if ( self.use_stdout == true ) then
        print ( cut )
    end
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

function LogNode:send_debug( from, msg )
    self:send( "DEBUG", from, msg )
end

function LogNode:run( port )
    self:set_cut()
    net.run ( port, self.name,
              function ( msg ) self:send_info ( self.name, msg ) end
            )
end
