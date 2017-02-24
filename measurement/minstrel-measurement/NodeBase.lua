
require ('rpc')
require ('spawn_pipe')
local unistd = require ('posix.unistd')
require ('parentpid')
require ('parsers/proc_version')
require ('Uci')

NodeBase = { name = nil
           , ctrl = nil
           , log_ctrl = nil
           , log_port = nil
           , proc_version = nil
           }

function NodeBase:new ( o )
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- fixme: try to catch address in use
function NodeBase:run( port )
    if rpc.mode == "tcpip" then
        self:send_info ( "Service " .. self.name .. " started" )
        local fname = "/proc/version"
        local file = io.open ( fname )
        local line = file:read("*l")
        self.proc_version = parse_proc_version ( line )
        file:close()
        self:send_info ( self.proc_version:__tostring() )
        self:set_cut ()
        rpc.server ( port )
    else
        self:send_error ( "Err: tcp/ip supported only" )
    end
end

function NodeBase:set_nameserver (  nameserver )
    set_resolvconf ( nameserver )
end

-- -------------------------
-- date
-- -------------------------

function NodeBase:set_date ( year, month, day, hour, min, second )
    if ( self.proc_version.system == "LEDE" ) then
        -- use busybox date
        return set_date_bb ( year, month, day, hour, min, second )
    else
        -- use coreutile date
        return set_date_core ( year, month, day, hour, min, second )
    end
end

-- -------------------------
-- posix
-- -------------------------

function NodeBase:get_pid()
    local lua_pid = unistd.getpid()
    return lua_pid
end

-- kill child process of lua by pid
-- if process with pid is not a child of lua
-- then return nil
-- otherwise the exit code of kill is returned
function NodeBase:kill ( pid, signal )
    local lua_pid = unistd.getpid()
    if (parent_pid ( pid ) == lua_pid) then
        local kill
        if (signal ~= nil) then
            kill = spawn_pipe("kill", "-" .. signal, pid)
        else
            kill = spawn_pipe("kill", pid)
        end
        local exit_code = kill['proc']:wait()
        close_proc_pipes ( kill )
        return exit_code
    else 
        self:send_warning("try to kill pid " .. pid)
        return nil
    end
    -- TODO: creates zombies
end

-- -------------------------
-- Logging
-- -------------------------

function NodeBase:connect_logger ()
    function connect ()
        local l, e = rpc.connect (self.log_ctrl.addr, self.log_port)
        return l, e
    end
    local status
    local logger
    local err
    local retrys = 5
    repeat
        status, logger, err = pcall ( connect )
        retrys = retrys -1
        if ( status == false ) then os.sleep (1) end
    until status == true or retrys == 0
    -- TODO: print this message a single time only
    if (status == false) then
        print ( "Err: Connection to Logger failed" )
        local addr = "none"
        if ( self.log_ctrl ~= nil and self.log_ctrl.addr ~= nil ) then addr = self.log_ctrl.addr end
        print ( "Err: no logger at address: " .. addr
                                              .. " on port: " .. ( self.log_port or "none" ) )
        return nil
    else
        return logger
    end
end

function NodeBase:disconnect_logger ( logger )
    if (logger ~= nil) then
        rpc.close (logger)
    end
end

function NodeBase:set_cut ()
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.set_cut ()    
    end
    self:disconnect_logger ( logger )
end

function NodeBase:send_error( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_error( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end

function NodeBase:send_info( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_info( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end

function NodeBase:send_warning( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_warning( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end

function NodeBase:send_debug( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_debug( self.name, msg )
    end
    self:disconnect_logger ( logger )
end
