require ('misc')
require ('pcap')
require ('parsers/radiotap')

local misc = require ('misc')

FXsnrAnalyser = { aps = nil
                , stas = nil
                , measurements = nil
                }

function FXsnrAnalyser:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function FXsnrAnalyser:create ( aps, stas )
    local o = FXsnrAnalyser:new( { aps = aps, stas = stas } )
    o.measurements = {}
    return o
end

function FXsnrAnalyser:add_measurement ( m )
    self.measurements [ #self.measurements + 1 ] = m
end

-- duplicate of experiment:get_rate
function FXsnrAnalyser:get_rate( key )
    return split ( key, "-" ) [1]
end

-- duplicate of experiment:get_rate
function FXsnrAnalyser:get_power( key )
    return split ( key, "-" ) [2]
end

function FXsnrAnalyser:min ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local min = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v < min ) then min = v end
    end
    return min
end

function FXsnrAnalyser:max ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local max = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v > max ) then max = v end
    end
    return max
end

function FXsnrAnalyser:avg ( t )
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

function FXsnrAnalyser:read_ssid ( dir, name )
    local ssid = nil
    local fname = dir .. "/" .. name .. "/ssid.txt"
    print ( fname )
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

-- returns list of SNRs stats (MIN/MAX/AVG) for each measurement
-- stored in map indexed by a string concatenated by power and rate 
-- and MIN/MAX/AVG seperated by "-"
function FXsnrAnalyser:snrs ()
    local ret = {}
    
    for _, measurement in ipairs ( self.measurements ) do

        local snrs = {}
        local min_snr
        local max_snr
        local avg_snr

        for key, stats in pairs ( measurement.tcpdump_pcaps ) do
        
            if ( table_size ( split ( key, "-" ) ) ~= 3 ) then break end

            local rate = self:get_rate ( key )
            local power = self:get_power ( key )

            local fname = measurement.output_dir .. "/" .. measurement.node_name 
                            .. "/" .. measurement.node_name .. "-" .. key .. ".pcap"
            -- local file = io.open(fname, "wb")
            --file:write ( stats )
            --file:close()
            local ssid_m = self:read_ssid ( measurement.output_dir, measurement.node_name )
            print ( ssid_m )
            print ( measurement.node_name )
            print ( "mac: " .. measurement.node_mac )
            print ( "macs: " .. table_tostring ( measurement.opposite_macs ) )
            local cap = pcap.open_offline ( fname )
            if (cap ~= nil) then
	            cap:set_filter ("type mgt subtype beacon", nooptimize)
            
                for capdata, timestamp, wirelen in cap.next, cap do
                    local rest = capdata
                    local radiotap_header
                    local radiotap_data
                    radiotap_header, rest = PCAP.parse_radiotap_header ( rest )
                    radiotap_data, rest = PCAP.parse_radiotap_data ( rest )
		            local ssid = radiotap_data [ 'ssid' ]
		            local frame_type = radiotap_data [ 'type' ]
                    --print ( "type:" .. frame_type )
		            local frame_subtype = radiotap_data [ 'subtype' ]
                    --print ( "subtype:" .. frame_subtype )
                    local sa = PCAP.mac_tostring ( radiotap_data [ 'sa' ] )
                    local da = PCAP.mac_tostring ( radiotap_data [ 'da' ] )
                    if ( ssid == ssid_m
                        and frame_type == 2
                        and PCAP.radiotap_data_frametype [ frame_subtype + 1  ] == "DATA"
                        and ( ( da == "ff:ff:ff:ff:ff:ff" and ( misc.index_of ( sa, measurement.opposite_macs ) ~= nil or sa == measurement.node_mac ) )
                                  or ( misc.index_of ( sa, measurement.opposite_macs ) ~= nil and sa == measurement.node_mac ) ) ) then
                	    --print ( "tsft: " .. ( radiotap_header ['tsft'] or "not present" ) )
                        --print ( ssid )
                        --print ( "antenna_signal: " .. ( radiotap_header ['antenna_signal'] or "not present" ) )
                        --print ( "rate: " .. ( radiotap_header ['rate'] or "not present" ) )
                        if ( radiotap_header ['antenna_signal'] ~= nil ) then
                            snrs [ #snrs + 1 ] = radiotap_header ['antenna_signal']
                        end
                    end
                end

                cap:close()
            else
                print ("FXsnrAnalyser: pcap open failed: " .. fname)
            end

            if ( table_size ( snrs ) > 0 ) then
                ret [ power .. "-" .. rate .. "-MIN" ] = self:min ( snrs )
                ret [ power .. "-" .. rate .. "-MAX" ] = self:max ( snrs )
                ret [ power .. "-" .. rate .. "-AVG" ] = self:avg ( snrs )
            end
        end
    end

    return ret
end
