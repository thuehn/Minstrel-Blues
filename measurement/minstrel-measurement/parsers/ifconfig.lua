require ('parsers/parsers')

-- wlan1     Link encap:Ethernet  HWaddr A0:F3:C1:64:81:7C 
--           inet addr:192.168.2.13  Bcast:192.168.2.255  Mask:255.255.255.0
-- unl0     Link encap:UNSPEC  HWaddr 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00 (not implemented)
-- lo        Link encap:Local Loopback (not implemented)
-- ifconfig: wlan2: error fetching interface information: Device not found

-- eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
--        inet 192.168.2.21  netmask 255.255.255.0  broadcast 192.168.2.255
--        inet6 fe80::2e0:4cff:fe68:1fc  prefixlen 64  scopeid 0x20<link>
--        ether 00:e0:4c:68:01:fc  txqueuelen 1000  (Ethernet)
-- wlan0: error fetching interface information: Device not found
 

IfConfig = { iface = nil, encap = nil, mac = nil, addr = nil }
function IfConfig:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function IfConfig:create ()
    local o = IfConfig:new()
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

    function parse_ifconfig_lede ( iface, ifconfig )

        local rest = ifconfig
        local state = true
        local mac = nil
        local encap = nil
    
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
        if ( mac ~= nil ) then
            out.mac = string.lower ( mac )
        end
        out.iface = iface
        out.addr = addr
        return out
    end

    function parse_ifconfig_linux ( iface, ifconfig )

        function parse_flags ( flags )
            local rest = flags
            local state
            local flags = {}
            repeat
                local flag
                local c = shead ( rest )
                if ( c == ',' ) then
                    rest = stail ( rest )
                end
                flag, rest = parse_ide ( rest )
                flags [ #flags + 1 ] = flag
            until c == '>'
            return flags, rest
        end

        local out = IfConfig:create()

        local rest = ifconfig
        local state = true
        local mac = nil
        local encap = nil

        rest = stail ( rest ) -- :
        rest = skip_layout ( rest )
        state, rest = parse_str ( rest, "flags=" )
        _, rest = parse_num ( rest )
        state, rest = parse_str ( rest, "<" )
        _, rest = parse_flags ( rest )
        state, rest = parse_str ( rest, ">" )
        rest = skip_layout ( rest )
        state, rest = parse_str ( rest, "mtu" )
        rest = skip_layout ( rest )
        _, rest = parse_num ( rest )
        rest = skip_layout ( rest )
        state, rest = parse_str ( rest, "inet" )
        rest = skip_layout ( rest )
        addr, rest = parse_ipv4 ( rest )
        rest = skip_layout ( rest )
        state, rest = parse_str ( rest, "netmask" )
        rest = skip_layout ( rest )
        _, rest = parse_ipv4 ( rest )
        rest = skip_layout ( rest )
        state, rest = parse_str ( rest, "broadcast" )
        rest = skip_layout ( rest )
        _, rest = parse_ipv4 ( rest )
        -- ...
    
        out.iface = iface
        out.encap = encap
        if ( mac ~= nil ) then
            out.mac = string.lower ( mac )
        end
        out.addr = addr
        return out
    end

    if ( ifconfig == nil or ifconfig == "" ) then
        return IfConfig:create()
    end

    local rest = ifconfig
    local iface

    local add_chars = {}
    add_chars[1] = '-'
    iface, rest = parse_ide ( rest, add_chars )
    
    if ( shead ( rest ) == ':' ) then
        return parse_ifconfig_linux ( iface, rest )
    else
        return parse_ifconfig_lede ( iface, rest )
    end
    
end
