require ('misc')
require ('parsers/iperf')

local pprint = require ('pprint')
local misc = require ('misc')

BandwidthAnalyser = { aps = nil
                    , stas = nil
                    }

function BandwidthAnalyser:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function BandwidthAnalyser:create ( aps, stas )
    local o = BandwidthAnalyser:new( { aps = aps, stas = stas } )
    return o
end

-- duplicate of experiment:get_rate
function BandwidthAnalyser:get_rate ( key )
    return split ( key, "-" ) [1]
end

-- duplicate of experiment:get_rate
function BandwidthAnalyser:get_power ( key )
    return split ( key, "-" ) [2]
end

function BandwidthAnalyser:min ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local min = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v < min ) then min = v end
    end
    return min
end

function BandwidthAnalyser:max ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local max = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v > max ) then max = v end
    end
    return max
end

function BandwidthAnalyser:avg ( t )
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

function BandwidthAnalyser:read_ssid ( dir, name )
    local ssid = nil
    local fname = dir .. "/" .. name .. "/ssid.txt"
    local file = io.open ( fname )
    if ( file ~= nil ) then
        local content = file:read ( "*a" )
        if ( content ~= nil ) then
            ssid = string.sub ( content, 1, #content - 1 )
        end
        file:close()
    end
    return ssid
end

function BandwidthAnalyser:write_bandwidths ( fname, bandwidths )
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        for i, bandwidth in ipairs ( bandwidths ) do
            if ( i ~= 1 ) then file:write ( "," ) end
            file:write ( bandwidth )
        end
        file:close ()
    end
end

function BandwidthAnalyser:read_bandwidths ( fname )
    local bandwidths = {}
    local file = io.open ( fname, "r" )
    if ( file ~= nil ) then
        local bandwidths_str = split ( file:read ( "*a" ), "," )
        for _, bandwidth in ipairs ( bandwidths_str ) do
            bandwidths [ #bandwidths + 1 ] = tonumber ( bandwidth )
        end
        file:close ()
    end
    return bandwidths
end

function BandwidthAnalyser:calc_bandwidths_stats ( bandwidths, power, rate )
    local ret = {}
    if ( table_size ( bandwidths ) > 0 ) then
        local unique_bandwidths = misc.Set_count ( bandwidths )
        --for bandwidth, count in pairs ( unique_bandwidths ) do
        --    print ( "bandwidth: " .. bandwidth, count )
        --end

        ret [ power .. "-" .. rate .. "-MIN" ] = self:min ( bandwidths )
        ret [ power .. "-" .. rate .. "-MAX" ] = self:max ( bandwidths )
        ret [ power .. "-" .. rate .. "-AVG" ] = misc.round ( self:avg ( bandwidths ) )
    end
    return ret
end

function BandwidthAnalyser:bandwidths ( measurement )
    local ret = {}
    
    local base_dir = measurement.output_dir .. "/" .. measurement.node_name

    for key, stats in pairs ( measurement.iperf_c_outs ) do
        local bandwidths_fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-bandwidths.txt"
        local bandwidths = {}
        if ( isFile ( bandwidths_fname ) == false ) then
            if ( table_size ( split ( key, "-" ) ) < 3 ) then
                print ( "ERROR: unsupported key encoding" )
                break
            end
            local fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-iperf_client.txt"
            print ( fname )

            if ( isFile ( fname ) == true ) then
                local file = io.open ( fname, "r" )
                local content = file:read ( "*a" )
                file:close ()
                if ( content ~= nil and content ~= "" ) then
                    for _, iperf_str in ipairs ( split ( content, "\n" ) ) do
                        local iperf = parse_iperf_client ( iperf_str )
                        if ( iperf.id ~= nil ) then
                            bandwidths [ #bandwidths + 1 ] = iperf.bandwidth
                        end
                    end
                    self:write_bandwidths ( bandwidths_fname, bandwidths )
                end
            end
        else
            print ( bandwidths_fname )
            bandwidths = self:read_bandwidths ( bandwidths_fname )
        end
        pprint ( bandwidths )

        local rate = self:get_rate ( key )
        local power = self:get_power ( key )
        local bandwidths_stats = self:calc_bandwidths_stats ( bandwidths, power, rate )
        merge_map ( bandwidths_stats, ret )
    end

    return ret
end
