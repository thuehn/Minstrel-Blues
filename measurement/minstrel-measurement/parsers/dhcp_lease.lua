
require ('parsers/parsers')

DhcpLease = { timestamp = nil, mac = nil, addr = nil, hostname = nil, addr6 }
function DhcpLease:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function DhcpLease:create ()
    local o = DhcpLease:new()
    return o
end

function DhcpLease:__tostring() 
    local timestamp = "nil"
    if (self.timestamp ~= nil) then timestamp = self.timestamp end
    local mac = "nil"
    if (self.mac ~= nil) then mac = self.mac end
    local addr = "nil"
    if (self.addr ~= nil) then addr = self.addr end
    local hostname = "nil"
    if (self.hostname ~= nil) then hostname = self.hostname end
    local addr6 = "nil"
    if (self.addr6 ~= nil) then addr6 = self.addr6 end
    return "DhcpLease timestamp: " .. timestamp
            .. " mac: " .. mac
            .. " hostname: " .. hostname
            .. " addr: " .. addr
            .. " addr6: " .. addr6
end

function parse_dhcp_lease ( ifconfig )

    local rest = ifconfig
    local state = true
    local timestamp = nil
    local mac = nil
    local addr = nil
    local hostname = nil
    local addr6 = nil

    timestamp, rest = parse_num ( rest )
    rest = skip_layout( rest )
    mac, rest = parse_mac ( rest )
    rest = skip_layout( rest )
    addr, rest = parse_ipv4 ( rest )
    rest = skip_layout( rest )
    local add_chars = {}
    add_chars[1] = "*"
    hostname, rest = parse_ide ( rest, add_chars )
    rest = skip_layout( rest )
    -- ... addr6 | '*'
    
    local out = DhcpLease:create()
    out.timestamp = tonumber ( timestamp )
    out.mac = string.lower ( mac )
    out.hostname = hostname
    out.addr = addr
    out.addr6 = addr6
    return out
end
