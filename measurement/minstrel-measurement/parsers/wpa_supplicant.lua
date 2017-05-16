require ('parsers/parsers')
local pprint = require ('pprint')

WpaSupplicant = { ssid = nil
                , priority = nil
                , mode = nil
                , key_mgmt = nil
                , psk = nil
                , auth_alg = nil
                , proto = nil
                , group = nil
                , pairwise = nil
                , unknown = nil
                }

function WpaSupplicant:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function WpaSupplicant:create ()
    local o = WpaSupplicant:new ()
    o.unknown = {}
    return o
end

function WpaSupplicant:__tostring ()
    local unknown = ""
    for name, value in pairs ( self.unknown ) do
        unknown = unknown .. name .. " = " .. value .. "\n"
    end
    return "WpaSupplicant ssid: " .. ( self.id or "unset" )
            .. " priority: " .. ( self.priority or "unset" )
            .. " mode: " .. ( self.mode or "unset" )
            .. " key_mgmt: " .. ( self.key_mgmt or "unset" )
            .. " psk: " .. ( self.psk or "unset" )
            .. " auth_alg: " .. ( self.auth_alg or "unset" )
            .. " proto: " .. ( self.proto or "unset" )
            .. " group: " .. ( self.group or "unset" )
            .. " pairwise: " .. ( self.pairwise or "unset" )
            .. " unknown: " .. unknown
end

function parse_wpa_supplicant_conf ( conf )
    
    local out = {}

    if ( conf == nil ) then return out end
    if ( string.len ( conf ) == 0 ) then return out end

    local rest = conf
    local pos = 0
    local state = true
    local name
    local value

    while ( rest ~= "" ) do
        local c = shead ( rest )
        if ( c == "#" ) then
            state, rest, pos = skip_line_comment ( rest, "#", pos )
        elseif ( c == "\n" ) then
            rest = stail ( rest )
            pos = cursor ( pos )
        else
            name, rest, pos = parse_ide ( rest, { '_' }, pos )
            rest, pos = skip_layout ( rest, pos )

            state, rest, pos = parse_str ( rest, "=", pos )
            rest, pos = skip_layout ( rest, pos )

            state, rest, pos = parse_str ( rest, "{", pos )
            if ( state == false ) then
                value, rest, pos = parse_until ( rest, "\n", pos )
            else
                if ( name == "network" ) then
                    local network
                    state, rest, pos = parse_str ( rest, "\n", pos )
                    network, rest, pos = parse_wpa_supplicant ( rest, pos )
                    out [ #out + 1 ] = network
                end
            end
        end
    end

    return out
end

function parse_wpa_supplicant ( network, pos )

    local out = WpaSupplicant:create ()

    local rest = network
    local state = true

    while ( shead ( rest ) ~= "}" ) do
        rest, pos = skip_layout ( rest, pos )
        name, rest, pos = parse_ide ( rest, { '_' }, pos )

        rest, pos = skip_layout ( rest, pos )
        state, rest, pos = parse_str ( rest, "=", pos )

        rest, pos, pos = skip_layout ( rest, pos )
        value, rest, pos = parse_until ( rest, "\n", pos )
        state, rest, pos = parse_str ( rest, "\n", pos )

        if ( name == "ssid" ) then
            out.ssid = value 
        elseif ( name == "priority" ) then
            out.priority = value
        elseif ( name == "mode" ) then
            out.mode = value
        elseif ( name == "key_mgmt" ) then
            out.key_mgmt = value
        elseif ( name == "psk" ) then
            out.psk = value
        elseif ( name == "auth_alg" ) then
            out.auth_alg = value
        elseif ( name == "proto" ) then
            out.proto = value
        elseif ( name == "group" ) then
            out.group = value
        elseif ( name == "pairwise" ) then
            out.pairwise = value
        else
            out.unknown [ name ] = value 
        end
    end
    rest = stail ( rest )
    pos = cursor ( pos )
    return out, rest, pos
end
