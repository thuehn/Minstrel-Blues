
-- TODO: use lua rClient / rServe for passing data to R
-- pprint = require ('pprint')

SNRRenderer = { snrs = nil
              , powers = nil
              , rates = nil
              }

function SNRRenderer:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function SNRRenderer:create ( snrs )
    local o = SNRRenderer:new( { snrs = snrs } )
    o.powers = {}
    o.rates = {}
    return o
end

function SNRRenderer:get_power ( key )
    return tonumber ( split ( key, "-" ) [1] )
end

function SNRRenderer:get_rate ( key )
    return tonumber ( split ( key, "-" ) [2] )
end

function SNRRenderer:get_stat ( key )
    return split ( key, "-" ) [3]
end

function SNRRenderer:add_power ( power )
    local exists = false
    for _, p in ipairs ( self.powers ) do
        if ( p == power ) then
            exists = true
            break
        end
    end
    if ( exists == false ) then
        self.powers [ #self.powers + 1 ] = power
    end
end

function SNRRenderer:add_rate ( rate )
    local exists = false
    for _, r in ipairs ( self.rates ) do
        if ( r == rate ) then
            exists = true
            break
        end
    end
    if ( exists == false ) then
        self.rates [ #self.rates + 1 ] = rate
    end
end

function SNRRenderer:get_power_idx ( power )
    for i, p in ipairs ( self.powers ) do
        if ( power == p ) then return i end
    end
    return nil
end

function SNRRenderer:get_rate_idx ( rate )
    for i, r in ipairs ( self.rates ) do
        if ( rate == r ) then return i end
    end
    return nil
end

-- x: rates
-- y: powers
function SNRRenderer:run ( basedir )
    local rates_fname = basedir .. "/rates.txt"
    local powers_fname = basedir .. "/powers.txt"
    local snrs_min_fname = basedir .. "/snrs-min.txt"
    local snrs_max_fname = basedir .. "/snrs-max.txt"
    local snrs_avg_fname = basedir .. "/snrs-avg.txt"

    local powers = {}
    local rates = {}
    for key, snr in pairs ( self.snrs ) do
        local power = self:get_power ( key )
        self:add_power ( power )
        local rate = self:get_rate ( key )
        self:add_rate ( rate )
    end

    local rates_file = io.open ( rates_fname, "w" )
    if ( rates_file ~= nil ) then
        for i, rate in ipairs ( self.rates ) do
            if ( i ~= 1 ) then rates_file:write (" ") end
            rates_file:write ( rate )
        end
        rates_file:write("\n")
        rates_file:close()
    end

    local powers_file = io.open ( powers_fname, "w" )
    if ( powers_file ~= nil ) then
        for i, power in ipairs ( self.powers ) do
            if ( i ~= 1 ) then powers_file:write (" ") end
            powers_file:write ( power )
        end
        powers_file:write("\n")
        powers_file:close()
    end

    local snr_mins = {}
    local snr_maxs = {}
    local snr_avgs = {}
    for _, power in ipairs ( self.powers ) do
        if ( snr_mins [ tostring ( power ) ] == nil ) then
            snr_mins [ tostring ( power ) ] = {}
        end

        if ( snr_maxs [ tostring ( power ) ] == nil ) then
            snr_maxs [ tostring ( power ) ] = {}
        end

        if ( snr_avgs [ tostring ( power ) ] == nil ) then
            snr_avgs [ tostring ( power ) ] = {}
        end

        for _, rate in ipairs ( self.rates ) do
            snr_mins [ tostring ( power ) ] [ tostring ( rate ) ] = nil
            snr_maxs [ tostring ( power ) ] [ tostring ( rate ) ] = nil
            snr_avgs [ tostring ( power ) ] [ tostring ( rate ) ] = nil
        end
    end

    for key, snr in pairs ( self.snrs ) do
        local power = tostring ( self:get_power ( key ) )
        local rate = tostring ( self:get_rate ( key ) )
        local stat = self:get_stat ( key )
        if ( stat == "MIN" ) then
            snr_mins [ power ] [ rate ] = snr
        elseif ( stat == "MAX" ) then
            snr_maxs [ power ] [ rate ] = snr
        elseif ( stat == "AVG" ) then
            snr_avgs [ power ] [ rate ] = snr
        end
    end

    local snrs_min_file = io.open ( snrs_min_fname, "w" )
    if ( snrs_min_file ~= nil ) then
        for power, rates in pairs ( snr_mins ) do
            local first = true
            for rate, snr in pairs ( rates ) do
                if ( first ~= true ) then snrs_min_file:write (" ") else first = false end
                --print ( "min: " .. power .. " x " .. rate .. " = " .. ( snr or "NIL") )
                snrs_min_file:write ( ( snr or 0 ) )
            end
            snrs_min_file:write ( "\n" )
        end
        snrs_min_file:close ()
    end

    local snrs_max_file = io.open ( snrs_max_fname, "w" )
    if ( snrs_max_file ~= nil ) then
        for power, rates in pairs ( snr_maxs ) do
            local first = true
            for rate, snr in pairs ( rates ) do
                if ( first ~= true ) then snrs_max_file:write (" ") else first = false end
                --print ( "max: " .. power .. " x " .. rate .. " = " .. ( snr or "NIL") )
                snrs_max_file:write ( ( snr or 0 ) )
            end
            snrs_max_file:write ( "\n" )
        end
        snrs_max_file:close ()
    end

    local snrs_avg_file = io.open ( snrs_avg_fname, "w" )
    if ( snrs_avg_file ~= nil ) then
        for power, rates in pairs ( snr_avgs ) do
            local first = true
            for rate, snr in pairs ( rates ) do
                if ( first ~= true ) then snrs_avg_file:write (" ") else first = false end
                --print ( "avg: " .. power .. " x " .. rate .. " = " .. ( snr or "NIL" ) )
                snrs_avg_file:write ( ( snr or 0 ) )
            end
            snrs_avg_file:write ( "\n" )
        end
        snrs_avg_file:close ()
    end
    -- spawn R script to generate image
end
