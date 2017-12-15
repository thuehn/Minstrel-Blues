require ('parsers/parsers')
local pprint = require ('pprint')
local misc = require ('misc')

-- String name, String typ, String value
-- "expermiment_order", "List", "{1}"
-- "mac", "mac", "AA:22:BB:33:CC:44"
-- "mac_br", "mac", "AA:22:BB:33:CC:44"
-- "opposite_macs","List","{...}"
-- "opposite_macs_br","List","{...}"
-- "stations","List","{tp4300}"

MeasurementsOption = { name = nil
                     , typ = nil
                     , value = nil
                     }

function MeasurementsOption:new (o)
    local o = o or {}
    setmetatable ( o, self )
    self.__index = self
    return o
end

function MeasurementsOption:create ( name, typ, value )
    local o = MeasurementsOption:new ( { name = name
                                       , typ = typ
                                       , value = value
                                       } )
    return o
end

function MeasurementsOption:__tostring ()
    local out = self.name or "none"
    out = out .. ":"
    out = self.typ or "none"
    out = out .. "="
    if ( self.typ == "String" ) then
        out = out .. tostring ( self.value ) 
    elseif ( self.typ == "List" ) then
        for i, val in ipairs ( self.value ) do
            if ( i ~= 1 ) then out = out .. "," end
            out = out .. tostring ( val )
        end
    end
    return out
end

-- returns a list of MeasurementsOptions from file "options.txt" in directory "dir"
function MeasurementsOption.read_file ( dir )
    if ( dir == nil ) then
        return false, "input dir unset"
    end

    -- opposite macs
    local mopts = nil
    local fname = dir .. "/options.txt"
    local file = io.open ( fname )
    if ( file ~= nil ) then
        local content = file:read ( "*a" )
        if ( content ~= nil and content ~= "" ) then
            mopts = {}
            local options = split ( content, "\n" )
            table.remove ( options, #options )
            for _, option in pairs ( options ) do
                local name = nil
                local typ = nil
                local value = nil
                local state = nil
                local add_chars = { '_' }
                name, option = parse_ide ( option, add_chars ) 
                state, option = parse_str ( option, ":" )
                typ, option = parse_ide ( option, add_chars ) 
                state, option = parse_str ( option, "=" )
                if ( typ == "String" ) then
                    value = option
                elseif ( typ == "List" ) then
                    if ( option ~= "" ) then
                        value = split ( option, "," )
                    else
                        value = {}
                    end
                end
                mopts [ name ] = MeasurementsOption:create ( name, typ, value )
            end
        end
        file:close()
        return true, mopts
    end
    return false, "file not found or empty" 
end

function MeasurementsOption.write_file ( dir, mopts )
    if ( dir == nil ) then
        return false, "input dir unset"
    end
    if ( mopts == nil ) then
        return false, "measurements options unset"
    end
    local fname = dir .. "/options.txt"
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        for _, option in pairs ( mopts ) do
            local line = ( option.name or "none" ) 
                           .. ":" .. ( option.typ or "none" )
            line = line .. "="
            if ( option.typ == "String" ) then
                line = line  .. ( option.value or "" )
            elseif ( option.typ == "List" and option.value ~= nil ) then
                for i, val in ipairs ( option.value ) do
                    if ( i ~= 1 ) then line = line .. "," end
                    line = line .. tostring ( val )
                end
            end
            line = line .. '\n'
            file:write ( line )
        end
        file:close ()
    end
    return true, nil
end
