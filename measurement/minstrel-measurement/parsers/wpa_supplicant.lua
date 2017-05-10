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
    local o = WpaSupplicant:new()
    o.unknown = {}
    return o
end

function WpaSupplicant:__tostring() 
    return "WpaSupplicant ssid: " .. ( self.id or "unset" )
            .. " priority: " .. ( self.priority or "unset" )
            .. " mode: " .. ( self.mode or "unset" )
            .. " key_mgmt: " .. ( self.key_mgmt or "unset" )
            .. " psk: " .. ( self.psk or "unset" )
            .. " auth_alg: " .. ( self.auth_alg or "unset" )
            .. " proto: " .. ( self.proto or "unset" )
            .. " group: " .. ( self.group or "unset" )
            .. " pairwise: " .. ( self.pairwise or "unset" )
end

function parse_wpa_supplicant_conf ( conf )
    
    local out = {}

    if ( conf == nil ) then return out end
    if ( string.len ( conf ) == 0 ) then return out end

    local rest = conf
    local state = true
    local name
    local value

    while ( rest ~= "" ) do
        local c = shead ( rest )
        if ( c == "#" ) then
            state, rest = skip_line_comment ( rest, "#" )
        elseif ( c == "\n" ) then
            rest = stail ( rest )
        else
            name, rest = parse_ide ( rest )
            rest = skip_layout ( rest )
            state, rest = parse_str ( rest, "=" )
            rest = skip_layout ( rest )
            state, rest = parse_str ( rest, "{" )
            if ( state == false ) then
                value, rest = parse_until ( rest, "\n" )
            else
                if ( name == "network" ) then
                    state, rest = parse_str ( rest, "\n" )
                    local network = parse_wpa_supplicant ( rest )
                    out [ #out + 1 ] = network
                end
            end
        end
    end

    return out
end

function parse_wpa_supplicant ( network )

    local out = WpaSupplicant:create ()

    local rest = network
    local state = true

    while ( shead ( rest ) ~= "}" ) do
        rest = skip_layout ( rest )
        name, rest = parse_ide ( rest )
        rest = skip_layout ( rest )
        state, rest = parse_str ( rest, "=" )
        rest = skip_layout ( rest )
        value, rest = parse_until ( rest, "\n" )
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
        state, rest = parse_str ( rest, "\n" )
    end

    return out
end
