-- simple struct to store the name, the interface and the ip address of a host
-- i.e. for pretty printing and have a named triple instead of unprintable
-- table with keys

NetIF = { name = nil, iface = nil, addr = nil, mon = nil }
function NetIF:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NetIF:create ( name, iface, addr, mon )
    o = NetIF:new({ name = name, iface = iface, addr = addr, mon = mon })
    return o
end

function NetIF:__tostring() 
    local mon = "none"
    if (self.mon ~= nil) then
        mon = tostring(self.mon)
    end
    return self.name .. " :: " 
            .. "iface = " .. tostring(self.iface) .. ", " 
            .. "addr = " .. tostring(self.addr) .. ", "
            .. "mon = " .. mon 
end

