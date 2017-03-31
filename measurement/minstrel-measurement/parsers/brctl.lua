local misc = require ('misc')

require ('parsers/parsers')

BrCtrl = { name = nil
         , id = nil
         , stp_enabled = nil
         , interfaces = nil
         }

function BrCtrl:new (o)
    local o = o or {}
    setmetatable (o, self)
    self.__index = self
    return o
end

function BrCtrl:create ()
    local o = BrCtrl:new()
    return o
end

function BrCtrl:__tostring() 
    local out =  "BrCtrl name: " .. ( self.name or "unset" )
                .. " id: " .. ( self.id or "unset" )
                .. " interfaces: " .. ( table_tostring ( self.interfaces ) or "unset" )
    if ( self.stp_enabled ~= nil ) then
        out = out .. " stp_enabled: " .. tostring ( self.stp_enabled )
    end
    return out
end

function parse_brctl ( brctl )

    local out = BrCtrl:create()

    if ( brctl == nil ) then return out end
    if ( string.len ( brctl ) == 0 ) then return out end

    local rest = brctl
    local state = true
    local name = nil
    local id = nil
    local stp_enabled = false
    local interfaces = {}

    state, rest = parse_str ( rest, "bridge name" )
    if (state == false) then return out end
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "bridge id" )
    rest = skip_layout ( rest )
    state, rest = parse_str ( rest, "STP enabled" )
    rest = skip_layout ( rest )
    state, rest = parse_str ( rest, "interfaces" )
    rest = skip_layout ( rest )

    local add_chars = {}
    add_chars[1] = '-'
    add_chars[2] = '.'
    name, rest = parse_ide ( rest, add_chars )
    rest = skip_layout( rest )

    local add_dot = {}
    add_dot [1] = '.'
    id, rest = parse_ide ( rest, add_dot )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "no" )
    stp_enabled = not state
    if ( state == false ) then
        state, rest = parse_str ( rest, "yes" )
    end
    rest = skip_layout ( rest )

    while ( rest ~= nil and rest ~= "" ) do
        iface, rest = parse_ide ( rest, add_dot )
        interfaces [ # interfaces + 1 ] = iface
        rest = skip_layout( rest )
    end
    -- ...
    
    out.name = name
    out.id = id
    out.stp_enabled = stp_enabled
    out.interfaces = interfaces

    return out
end
