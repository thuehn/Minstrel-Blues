-- simple struct to store the name, the interface and the ip address of a host
-- i.e. for pretty printing and have a named triple instead of unprintable
-- table with keys

NetIF = { name = nil, iface = nil, addr = nil, mon = nil, phy = nil }
function NetIF:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NetIF:create ( name, iface, addr, mon, phy )
    local o = NetIF:new({ name = name, iface = iface, addr = addr, mon = mon, phy = phy })
    return o
end

function NetIF:__tostring() 
    local iface = "none"
    if (self.iface ~= nil) then
        iface = tostring(self.iface)
    end
    local addr = "none"
    if (self.addr ~= nil) then
        addr = tostring(self.addr)
    end
    local mon = "none"
    if (self.mon ~= nil) then
        mon = tostring(self.mon)
    end
    local phy = "none"
    if (self.phy ~= nil) then
        phy = tostring(self.phy)
    end
    return self.name .. " :: " 
            .. "iface = " .. iface .. ", " 
            .. "addr = " .. addr .. ", "
            .. "mon = " .. mon .. ", " 
            .. "phy = " .. phy 
end

