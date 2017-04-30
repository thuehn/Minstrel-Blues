require ('misc')

local pprint = require ('pprint')
local misc = require ('misc')

BandwidthTcpstatAnalyser = { aps = nil
                    , stas = nil
                    }

function BandwidthTcpstatAnalyser:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function BandwidthTcpstatAnalyser:create ( aps, stas )
    local o = BandwidthTcpstatAnalyser:new( { aps = aps, stas = stas } )
    return o
end

-- duplicate of experiment:get_rate
function BandwidthTcpstatAnalyser:get_rate ( key )
    return split ( key, "-" ) [1]
end

-- duplicate of experiment:get_rate
function BandwidthTcpstatAnalyser:get_power ( key )
    return split ( key, "-" ) [2]
end

function BandwidthTcpstatAnalyser:min ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local min = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v < min ) then min = v end
    end
    return min
end

function BandwidthTcpstatAnalyser:max ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local max = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v > max ) then max = v end
    end
    return max
end

function BandwidthTcpstatAnalyser:avg ( t )
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

function BandwidthTcpstatAnalyser:read_ssid ( dir, name )
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

function BandwidthTcpstatAnalyser:write_bandwidths ( fname, bandwidths )
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        for i, bandwidth in ipairs ( bandwidths ) do
            if ( i ~= 1 ) then file:write ( "," ) end
            file:write ( bandwidth )
        end
        file:close ()
    end
end

function BandwidthTcpstatAnalyser:read_bandwidths ( fname )
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

function BandwidthTcpstatAnalyser:calc_bandwidths_stats ( bandwidths, power, rate )
    local ret = {}
    if ( table_size ( bandwidths ) > 0 ) then
        ret [ power .. "-" .. rate .. "-MIN" ] = self:min ( bandwidths )
        ret [ power .. "-" .. rate .. "-MAX" ] = self:max ( bandwidths )
        ret [ power .. "-" .. rate .. "-AVG" ] = misc.round ( self:avg ( bandwidths ), 2 )
    end
    return ret
end

function BandwidthTcpstatAnalyser:bandwidths ( measurement )
    local ret = {}
    
    local base_dir = measurement.output_dir .. "/" .. measurement.node_name

    for key, stats in pairs ( measurement.tcpdump_pcaps ) do
        local bandwidths_fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-bandwidths.txt"
        local bandwidths = {}
        if ( isFile ( bandwidths_fname ) == false ) then
            if ( table_size ( split ( key, "-" ) ) < 3 ) then
                print ( "ERROR: unsupported key encoding" )
                break
            end
            local fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. ".pcap"
            
            print ( fname )

            if ( isFile ( fname ) == true ) then
                local content, exit_code = misc.execute ( "/usr/bin/tcpstat", "-r", fname, "-o", "%S %R %b \n", "1" )
                print ( content )
                if ( content ~= nil and content ~= "" ) then
                    for _, bandwidth_str in ipairs ( split ( content, "\n" ) ) do
                        --pprint ( bandwidth_str )
                        if ( bandwidth_str ~= "" ) then
                            local parts = split ( bandwidth_str , " " )
                            local ts = parts [ 1 ]
                            local id = parts [ 2 ]
                            local bandwidth = parts [ 3 ]
                            bandwidths [ #bandwidths + 1 ] = tonumber ( bandwidth / 1024 )
                       end
                    end
                    if ( table_size ( bandwidths ) == 0 ) then
                        bandwidths = { 0 }
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
