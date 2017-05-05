
require ('parsers/parsers')

Free = { total = nil
       , used = nil
       , free = nil 
       , shared = nil
       , buffers = nil
       , cached = nil
       }

function Free:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Free:create ()
    local o = Free:new()
    return o
end

function Free:__tostring() 
    return "total: " .. ( tostring ( self.total ) or "none" )
            .. " used: " .. ( tostring ( self.used ) or "none" )
            .. " free: " .. ( tostring ( self.free ) or "none" )
            .. " shared: " .. ( tostring ( self.shared ) or "none" )
            .. " buffers: " .. ( tostring ( self.buffers ) or "none" )
            .. " cached: " .. ( tostring ( self.cached ) or "none" )
end


function parse_free ( line )
    local state
    local rest = line
    local total
    local used
    local free
    local shared
    local buffers
    local cached

    rest = skip_layout ( rest )
    state, rest = parse_str( rest, "total" )
    rest = skip_layout ( rest )
    state, rest = parse_str( rest, "used" )
    rest = skip_layout ( rest )
    state, rest = parse_str( rest, "free" )
    rest = skip_layout ( rest )
    state, rest = parse_str( rest, "shared" )
    rest = skip_layout ( rest )
    state, rest = parse_str( rest, "buffers" )
    rest = skip_layout ( rest )
    state, rest = parse_str( rest, "cached" )
    rest = skip_layout ( rest )


    state, rest = parse_str( rest, "Mem:" )
    rest = skip_layout ( rest )
    total, rest = parse_num( rest )
    rest = skip_layout ( rest )
    used, rest = parse_num( rest )
    rest = skip_layout ( rest )
    free, rest = parse_num( rest )
    rest = skip_layout ( rest )
    shared, rest = parse_num( rest )
    rest = skip_layout ( rest )
    buffers, rest = parse_num( rest )
    rest = skip_layout ( rest )
    cached, rest = parse_num( rest )

    local free_m = Free:create()
    free_m.total = tonumber ( total )
    free_m.used = tonumber ( used )
    free_m.free = tonumber ( free )
    free_m.shared = tonumber ( shared )
    free_m.buffers = tonumber ( buffers )
    free_m.cached = tonumber ( cached )
    return free_m
end
