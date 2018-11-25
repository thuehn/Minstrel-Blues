require ('parsers/parsers')

NetStat = { proto = nil
         , recvq = nil
         , sendq = nil
         , local_addr = nil
         , local_port = nil
         , foreign_addr = nil
         , foreign_port = nil
         , state = nil
         , process = nil
         , program = nil
         }

function NetStat:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NetStat:create ()
    local o = NetStat:new()
    return o
end

function NetStat:__tostring() 
    return "NetStat proto: " .. ( self.proto or "unset" )
            .. " recvq: " .. ( self.recvq or "unset" )
            .. " sendq: " .. ( self.sendq or "unset" )
            .. " local_addr: " .. ( self.local_addr or "unset" )
            .. " local_port: " .. ( self.local_port or "unset" )
            .. " foreign_addr: " .. ( self.foreign_addr or "unset" )
            .. " foreign_port: " .. ( self.foreign_port or "unset" )
            .. " state: " .. ( self.state or "unset" )
            .. " process: " .. ( self.process or "unset" )
            .. " program: " .. ( self.program or "unset" )
end

function parse_netstat ( netstat )

    local out = {}

    if ( netstat == nil or netstat == "" ) then return out end
    if ( string.len ( netstat ) == 0 ) then return out end

    local rest = netstat
    local pstate = true
    local has_state = false
    local has_process = false

    -- i18n - https://github.com/kikito/i18n.lua
    pstate, rest = parse_str ( rest, "Aktive Internetverbindungen (Server und stehende Verbindungen)" )
    rest = skip_layout ( rest )
    pstate, rest = parse_str ( rest, "Active Internet connections (servers and established)" )
    rest = skip_layout ( rest )

    pstate, rest = parse_str ( rest, "Proto Recv-Q Send-Q Local Address           Foreign Address" )
    rest = skip_layout ( rest )

    has_state, rest = parse_str ( rest, "State" )
    if ( has_state == true ) then
        rest = skip_layout ( rest )
    end
    has_process, rest = parse_str ( rest, "PID/Program name" )
    if ( has_process == true ) then
        rest = skip_layout ( rest )
    end

    local i = 1
    while ( rest ~= nil and rest ~= "" and rest ~= '\n' ) do
        local proto = nil
        local recevq = nil
        local sendq = nil
        local local_addr = nil
        local local_port = nil
        local foreign_addr = nil
        local foreign_port = nil
        local state = nil
        local process = nil
        local program = nil

        proto, rest = parse_ide ( rest )
        rest = skip_layout ( rest )

        if ( proto == "tcp" or proto == "udp" ) then
            recvq, rest = parse_num ( rest )
            rest = skip_layout ( rest )

            sendq, rest = parse_num ( rest )
            rest = skip_layout ( rest )

            local_addr, rest = parse_ipv4 ( rest )
            if ( local_addr == nil ) then
                -- ipv6 addr
                rest = skip_until ( rest, '\n' )
                rest = skip_layout ( rest )
            else
                pstate, rest = parse_str ( rest, ":" )
                if ( string.sub ( rest, 1, 1) == '*' ) then
                    pstate, rest = parse_str ( rest, "*" )
                    local_port = "*"
                else
                    local_port, rest = parse_num ( rest )
                end
                rest = skip_layout ( rest )
                
                foreign_addr, rest = parse_ipv4 ( rest )
                pstate, rest = parse_str ( rest, ":" )
                if ( string.sub ( rest, 1, 1 ) == '*' ) then
                    pstate, rest = parse_str ( rest, "*" )
                    foreign_port = "*"
                else
                    foreign_port, rest = parse_num ( rest )
                end
                rest = skip_layout ( rest )

                if ( has_state == true and proto == "tcp" ) then
                    state, rest = parse_ide ( rest )
                    rest = skip_layout ( rest )
                end
                if ( has_process == true ) then
                    process, rest = parse_num ( rest )
                    if ( process == '-' ) then
                        process = nil
                    end
                    pstate, rest = parse_str ( rest, "/" )
                    program, rest = parse_ide ( rest )
                    rest = skip_layout ( rest )
                end

                out [i] = NetStat:create () 
                out [i].proto = proto
                out [i].recvq = tonumber ( recvq )
                out [i].sendq = tonumber ( sendq )
                out [i].local_addr = local_addr
                out [i].local_port = local_port
                out [i].foreign_addr = foreign_addr
                out [i].foreign_port = foreign_port
                out [i].state = state
                out [i].process = process
                out [i].program = program
                i = i + 1
            end
        else
            if ( rest ~= "" ) then
                rest = skip_until ( rest, '\n' )
                rest = skip_layout ( rest )
            end
        end
    end

    return out
end
