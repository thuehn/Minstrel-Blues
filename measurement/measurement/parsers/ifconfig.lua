require ('parsers/parsers')

-- wlan1     Link encap:Ethernet  HWaddr A0:F3:C1:64:81:7C 
--           inet addr:192.168.2.13  Bcast:192.168.2.255  Mask:255.255.255.0
-- unl0     Link encap:UNSPEC  HWaddr 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00 (not implemented)
-- lo        Link encap:Local Loopback (not implemented)

-- not implemented
-- eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
--        inet 192.168.2.21  netmask 255.255.255.0  broadcast 192.168.2.255
--        inet6 fe80::2e0:4cff:fe68:1fc  prefixlen 64  scopeid 0x20<link>
--        ether 00:e0:4c:68:01:fc  txqueuelen 1000  (Ethernet)
 

IfConfig = { iface = nil, encap = nil, mac = nil, addr = nil }
function IfConfig:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function IfConfig:create ()
    o = IfConfig:new()
    return o
end

function IfConfig:__tostring() 
    local addr = "nil"
    if (self.addr ~= nil) then addr = self.addr end
    local encap = "nil"
    if (self.encap ~= nil) then encap = self.encap end
    local mac = "nil"
    if (self.mac ~= nil) then mac = self.mac end
    local iface = "nil"
    if (self.iface ~= nil) then iface = self.iface end
    return "IfConfig encap: " .. encap
            .. " mac: " .. mac
            .. " iface: " .. iface
            .. " addr: " .. addr
end

function parse_ifconfig ( ifconfig )

    local rest = ifconfig
    local state = true
    local mac = nil
    local iface = nil
    local encap = nil

    iface, rest = parse_ide ( rest, '-' )
    rest = skip_layout( rest )
    state, rest = parse_str ( rest, "Link encap:" )
    encap, rest = parse_ide ( rest )
    rest = skip_layout( rest )
    state, rest = parse_str ( rest, "HWaddr" )
    rest = skip_layout( rest )
    mac, rest = parse_mac ( rest )
    rest = skip_layout( rest )
    state, rest = parse_str ( rest, "inet addr:" )
    addr, rest = parse_ipv4 ( rest )
    -- ...
    
    local out = IfConfig:create()
    out.encap = encap
    out.mac = mac
    out.iface = iface
    out.addr = addr
    return out
end
