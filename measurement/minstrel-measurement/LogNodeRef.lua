local net = require ('Net')

LogNodeRef = { addr = nil
             , port = nil
             }

function LogNodeRef:new (o)
    local o = o or {}
    setmetatable (o, self)
    self.__index = self
    return o
end

function LogNodeRef:create ( addr, port )
    local o = LogNodeRef:new { addr = addr
                             , port = port
                             }
    return o
end

function LogNodeRef:__tostring ()
    return ( addr or "no address" ) .. ( port or "no port") 
end

function LogNodeRef:connect ()
    return net.connect ( self.addr, self.port, 10, "Logger", 
                         function ( msg ) print ( msg ) end )
end

function LogNodeRef:disconnect ( logger )
    net.disconnect ( logger )
end

function LogNodeRef:set_cut ()
    local logger = self:connect ()
    if (logger ~= nil) then
        logger.set_cut ()    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_error ( name, msg )
    local logger = self:connect ()
    if (logger ~= nil) then
        logger.send_error ( name, msg )    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_info ( name, msg )
    local logger = self:connect ()
    if (logger ~= nil) then
        logger.send_info ( name, msg )    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_warning ( name, msg )
    local logger = self:connect ()
    if (logger ~= nil) then
        logger.send_warning ( name, msg )    
    end
    self:disconnect ( logger )
end

function LogNodeRef:send_debug ( name, msg )
    local logger = self:connect ()
    if (logger ~= nil) then
        logger.send_debug ( name, msg )
    end
    self:disconnect ( logger )
end
