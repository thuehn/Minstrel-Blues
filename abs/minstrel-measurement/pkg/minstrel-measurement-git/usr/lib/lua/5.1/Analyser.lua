
local misc = require ('misc')

Analyser = { aps = nil
           , stas = nil
           }

function Analyser:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Analyser:create ( aps, stas )
    local o = Analyser:new( { aps = aps, stas = stas } )
    return o
end

-- duplicate of experiment:get_rate
function Analyser:get_rate ( key )
    return split ( key, "-" ) [1]
end

-- duplicate of experiment:get_rate
function Analyser:get_power ( key )
    return split ( key, "-" ) [2]
end

function Analyser:min ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local min = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v < min ) then min = v end
    end
    return min
end

function Analyser:max ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local max = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v > max ) then max = v end
    end
    return max
end

function Analyser:avg ( t )
    local sum = 0
    local count = 0
    
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' ) then
            sum = sum + v
            count = count + 1
        end
    end
    return ( sum / count )
end

function Analyser:write ( fname, values )
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        for i, value in ipairs ( values ) do
            if ( i ~= 1 ) then file:write ( "," ) end
            file:write ( value )
        end
        file:close ()
    end
end

function Analyser:read ( fname )
    local values = {}
    local file = io.open ( fname, "r" )
    if ( file ~= nil ) then
        local values_str = split ( file:read ( "*a" ), "," )
        for _, value in ipairs ( values_str ) do
            values [ #values + 1 ] = tonumber ( value )
        end
        file:close ()
    end
    return values
end

function Analyser:calc_stats ( values, power, rate )
    local ret = {}
    if ( table_size ( values ) > 0 ) then
        local unique_values = misc.Set_count ( values )
        ret [ power .. "-" .. rate .. "-WAVG" ] = unique_values
        ret [ power .. "-" .. rate .. "-MIN" ] = self:min ( values )
        ret [ power .. "-" .. rate .. "-MAX" ] = self:max ( values )
        ret [ power .. "-" .. rate .. "-AVG" ] = misc.round ( self:avg ( values ) )
    end
    return ret
end

