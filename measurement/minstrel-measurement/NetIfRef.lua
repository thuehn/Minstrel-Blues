
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
    local ctrl_ip, rest = parse_ipv4 ( name )
    ctrl_net.addr = ctrl_ip
    if ( ctrl_net.addr == nil ) then
        -- name is a host name (and bo ip address)
        local ip_addr, _ = net.lookup ( name )
        if ( ip_addr ~= nil ) then
            ctrl_net.addr = ip_addr
        end 
    end
end
