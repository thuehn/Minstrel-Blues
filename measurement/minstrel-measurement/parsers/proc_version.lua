
require ('parsers/parsers')


ProcVersion = { lx_version = nil
              , lx_build_user = nil
              , gcc_version = nil
              , system = nil
              , num_cpu = nil
              , smp_enabled = nil
              , date = nil
              }

function ProcVersion:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ProcVersion:create ()
    local o = ProcVersion:new()
    return o
end

function ProcVersion:__tostring() 
    return "ProcVersion ::"
        .. " lx version: " .. ( self.lx_version or "none" )
        .. " lx build user: " .. ( self.lx_build_user or "none" )
        .. " gcc version: " .. ( self.gcc_version or "none" )
        .. " system: " .. ( self.system or "none" )
        .. " num_cpu: " .. ( tostring ( self.num_cpu ) or "none" )
        .. " smp_enabled: " .. ( tostring ( self.smp_enabled ) or "none" )
        .. " date: " .. ( self.date or "none" )
end

function parse_proc_version ( str )

    local rest = str
    local state
    local num1
    local num2
    local num3
    local c
    local ide
    local add_chars = {}

    local lx_version = ""
    local lx_build_user
    local gcc_version = ""
    local system
    local num_cpu
    local smp_enabled

    state, rest = parse_str ( rest, "Linux version")
    rest = skip_layout ( rest )
    num1, rest = parse_num ( rest )
    state, rest = parse_str ( rest, ".")
    num2, rest = parse_num ( rest )
    state, rest = parse_str ( rest, ".")
    num3, rest = parse_num ( rest )
    lx_version = num1 .. "." .. num2 .. "." .. num3

    c = shead ( rest )
    if ( c == '-' ) then
        rest = stail ( rest )
        ide, rest = parse_ide ( rest )
        lx_version = lx_version .. "-" .. ide
    end 

    rest = skip_layout ( rest )
    state, rest = parse_str ( rest, "(")
    add_chars[1] = '@'
    lx_build_user, rest = parse_ide ( rest, add_chars )
    state, rest = parse_str ( rest, ")")

    rest = skip_layout ( rest )
    state, rest = parse_str ( rest, "(gcc version ")
    num1, rest = parse_num ( rest )
    state, rest = parse_str ( rest, ".")
    num2, rest = parse_num ( rest )
    state, rest = parse_str ( rest, ".")
    num3, rest = parse_num ( rest )
    gcc_version = num1 .. "." .. num2 .. "." .. num3

    state, rest = parse_str ( rest, " (")
    system, rest = parse_ide ( rest )
    rest = skip_until ( rest, ')' )
    state, rest = parse_str ( rest, ")")
    rest = skip_layout ( rest )
    state, rest = parse_str ( rest, ")")

    state, rest = parse_str ( rest, " #")
    num_cpu, rest = parse_num ( rest )
    rest = skip_layout ( rest )
    smp_enabled, rest = parse_str ( rest, "SMP")
    if ( smp_enabled ) then 
        rest = skip_layout ( rest )
    end
    date = rest

    local proc_version = ProcVersion:create()
    proc_version.lx_version = lx_version
    proc_version.lx_build_user = lx_build_user
    proc_version.gcc_version = gcc_version
    proc_version.system = system
    proc_version.num_cpu = tonumber ( num_cpu )
    proc_version.smp_enabled = smp_enabled
    proc_version.date = date

    return proc_version
end

local gentoo_sys = parse_proc_version ("Linux version 4.9.5-gentoo (root@sinope) (gcc version 4.9.4 (Gentoo 4.9.4 p1.0, pie-0.6.4) ) #4 SMP Mon Feb 20 16:49:22 CET 2017")
print ( gentoo_sys:__tostring() )
local lede_sys = parse_proc_version ("Linux version 4.4.49 (denis@sinope) (gcc version 5.4.0 (LEDE GCC 5.4.0 r3517-d6baeb5) ) #0 Fri Feb 17 09:30:48 2017")
print ( lede_sys:__tostring() )
