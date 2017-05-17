local net = require ('Net')
local ps = require ('posix.signal') --kill
local lpc = require 'lpc'
local misc = require ('misc')

LogNodeRef = { addr = nil
             , port = nil
             , pid = nil
             , retries = nil
             }

function LogNodeRef:new (o)
    local o = o or {}
    setmetatable (o, self)
    self.__index = self
    return o
end

function LogNodeRef:create ( addr, port, retries )
    local o = LogNodeRef:new { addr = addr
                             , port = port
                             , retries = retries
                             }
    return o
end

function LogNodeRef:__tostring ()
    return ( addr or "no address" ) .. ( port or "no port") 
end

function LogNodeRef:start ( log_file, lua_bin )
    self.pid, _, _ = misc.spawn ( lua_bin, "/usr/bin/runLogger", log_file
                                , "--port", self.port )
end

function LogNodeRef:connect ()
    return net.connect ( self.addr, self.port, self.retries, "Logger", print )
end

function LogNodeRef:disconnect ( logger )
    net.disconnect ( logger )
end

function LogNodeRef:set_cut ()
    local logger = self:connect ()
    if ( logger ~= nil ) then
        logger.set_cut ()    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_error ( name, msg )
    local logger = self:connect ()
    if ( logger ~= nil ) then
        logger.send_error ( name, msg )    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_info ( name, msg )
    local logger = self:connect ()
    if ( logger ~= nil ) then
        logger.send_info ( name, msg )    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_warning ( name, msg )
    local logger = self:connect ()
    if ( logger ~= nil ) then
        logger.send_warning ( name, msg )    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_debug ( name, msg )
    local logger = self:connect ()
    if ( logger ~= nil ) then
        logger.send_debug ( name, msg )
    end
    self:disconnect ( logger )
end

function LogNodeRef:stop ()
    local logger = self:connect ()
    if ( self.pid == nil ) then
        if ( logger ~= nil ) then
            logger.send_error ( "logger not stopped: pid is not set" )
        end
    else
        if ( logger ~= nil ) then
            logger.send_info ( "stop logger with pid " .. self.pid )
        end
    end
    if ( logger ~= nil ) then
        logger.stop () --close log file
    end
    self:disconnect ( logger )
    if ( self.pid ~= nil ) then
        ps.kill ( self.pid )
        lpc.wait ( self.pid )
    end
end

