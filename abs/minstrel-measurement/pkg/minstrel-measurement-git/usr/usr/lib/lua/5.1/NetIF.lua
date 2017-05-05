require ('Net')

-- simple struct to store the interface and the ip address of a host
-- i.e. for pretty printing and have a named triple instead of unprintable
-- table with keys

NetIF = { iface = nil, addr = nil, mon = nil, phy = nil, is_remote = nil }

function NetIF:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NetIF:create ( iface, addr, mon, phy )
    local o = NetIF:new( { iface = iface, addr = addr, mon = mon, phy = phy } )
    return o
end

function NetIF:__tostring() 
    return "iface = " .. ( self.iface or "none" ) .. ", "
            .. "addr = " .. ( self.addr or "none" ) .. ", "
            .. "mon = " .. ( self.mon or "none" ) .. ", "
            .. "phy = " .. ( self.phy  or "none" )
end

function NetIF:get_addr ()
    if ( self.addr == nil ) then
        self.addr, msg = Net.get_addr ( self.iface )
    end
    return self.addr
end

