require ('parsers/parsers')

Cpusage = { timestamp = nil, user = nil, nice = nil 
          , system = nil, idle = nil, iowait = nil
          , irq = nil, softirq = nil
          }

function Cpusage:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Cpusage:create ()
    local o = Cpusage:new()
    return o
end

function Cpusage:__tostring() 
    local user = "nil"
    if (self.user ~= nil) then user = self.user end
    local nice = "nil"
    if (self.nice ~= nil) then nice = self.nice end
    local system = "nil"
    if (self.system ~= nil) then system = self.system end
    local idle = "nil"
    if (self.idle ~= nil) then idle = self.idle end
    local iowait = "nil"
    if (self.iowait ~= nil) then iowait = self.iowait end
    local irq = "nil"
    if (self.irq ~= nil) then irq = self.irq end
    local softirq = "nil"
    if (self.softirq ~= nil) then softirq = self.softirq end
    return self.timestamp 
            .. " user: " .. user .. "%"
            .. " nice: " .. nice .. "%"
            .. " system: " .. system .. "%"
            .. " idle: " .. idle .. "%"
            .. " iowait: " .. iowait .. "%"
            .. " irq: " .. irq .. "%"
            .. " softirq: " .. softirq .. "%"
end


function parse_cpusage ( line )
    local state
    local rest
    local year
    local month
    local day
    local hour
    local second

    state, rest = parse_str( line, "timestamp: " )
    year, rest = parse_num( rest )
    state, rest = parse_str( rest, "-" )
    month, rest = parse_num( rest )
    state, rest = parse_str( rest, "-" )
    day, rest = parse_num( rest )

    rest = skip_layout ( rest )
        
    hour, rest = parse_num( rest )
    state, rest = parse_str( rest, "." )
    minute, rest = parse_num( rest )
    state, rest = parse_str( rest, "." )
    second, rest = parse_num( rest )

    state, rest = parse_str( rest, ", user: " )
    rest = skip_layout( rest )
    state, rest = parse_str( rest, "-" )
    local user = 0
    if (not state) then -- value
        user, rest = parse_real( rest )
    else -- -nan
        state, rest = parse_str( rest, "nan" )
    end

    state, rest = parse_str( rest, "%, nice: " )
    rest = skip_layout( rest )
    nice, rest = parse_real( rest )

    state, rest = parse_str( rest, "%, system: " )
    rest = skip_layout( rest )
    system, rest = parse_real( rest )

    state, rest = parse_str( rest, "%, idle: " )
    rest = skip_layout( rest )
    idle, rest = parse_real( rest )

    state, rest = parse_str( rest, "%, iowait: " )
    rest = skip_layout( rest )
    iowait, rest = parse_real( rest )

    state, rest = parse_str( rest, "%, irq: " )
    rest = skip_layout( rest )
    irq, rest = parse_real( rest )

    state, rest = parse_str( rest, "%, softirq: " )
    rest = skip_layout( rest )
    softirq, rest = parse_real( rest )

    local cpu = Cpusage:create()
    cpu.timestamp = year .. "-" .. month .. "-" .. day .. " " .. hour .. "." .. minute .. "." .. second
    cpu.user = user
    cpu.nice = nice
    cpu.system = system
    cpu.idle = idle
    cpu.iowait = iowait
    cpu.irq = irq
    cpu.softirq = softirq
    return cpu
end
