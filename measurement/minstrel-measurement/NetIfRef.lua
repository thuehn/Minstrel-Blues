
local net = require ('Net')

NetIfRef = { iface = nil
           , addr = nil
           , mon = nil
           , phy = nil
           , mac = nil
           }

function NetIfRef:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NetIfRef:create ( iface, addr, mon, phy, mac )
    local o = NetIfRef:new( { iface = iface
                            , addr = addr
                            , mon = mon
                            , phy = phy
                            , mac = mac
                            } )
    return o
end

function NetIfRef:__tostring() 
    return "iface = " .. ( self.iface or "none" ) .. ", "
            .. "addr = " .. ( self.addr or "none" ) .. ", "
            .. "mon = " .. ( self.mon or "none" ) .. ", "
            .. "phy = " .. ( self.phy or "none" ) .. ", "
            .. "mac = " .. ( self.mac  or "none" )
end

function NetIfRef:set_addr ( addr_or_name )
    local addr, rest = parse_ipv4 ( addr_or_name )
    if ( addr == nil ) then
        -- name is a host name (or ip address)
        local dig, _ = net.lookup ( addr_or_name )
        if ( dig ~= nil and dig.addr ~= nil ) then
            for _, addr in ipairs ( dig.addr ) do
                if ( net.ip_reachable ( addr ) ) then
                    self.addr = addr
                end
            end
            -- self.name = addr_or_name
        else
            self.addr = nil
            -- self.name = addr_or_name
        end 
    else
        self.addr = addr
    end
end
