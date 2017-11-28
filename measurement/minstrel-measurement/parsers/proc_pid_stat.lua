
require ('parsers/parsers')


ProcPidStat = { pid = nil
              , prog = nil
              , state = nil
              }

function ProcPidStat:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ProcPidStat:create ()
    local o = ProcPidStat:new()
    return o
end

function ProcPidStat:__tostring() 
    return "ProcPidStat ::"
        .. " pid: " .. ( self.pid or "none" )
        .. " program: " .. ( self.program or "none" )
        .. " state: " .. ( self.state or "none" )
end

function parse_proc_pid_stat ( str )

    local rest = str
    local state

    local pid
    local program
    local proc_state

    pid, rest = parse_num ( rest )
    rest = skip_layout ( rest )
    state, rest = parse_str ( rest, "(")
	local add_chars = {}
    program, rest = parse_ide ( rest, add_chars )
    state, rest = parse_str ( rest, ")")
    rest = skip_layout ( rest )
    proc_state, rest = parse_ide ( rest, add_chars )

    -- ...

    local out = ProcPidStat:create()
    out.pid = tonumber ( pid )
    out.program = program
    out.state = proc_state

    return out
end
