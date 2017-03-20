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

-- Filter for all data frames:              wlan.fc.type == 2
-- Filter for Data:                         wlan.fc.type_subtype == 32
-- Filter for QoS Data:                     wlan.fc.type_subtype == 40
-- Filter by the source address (SA):       wlan.sa == MAC_address
-- Filter by the destination address (DA):  wlan.da == MAC_address
-- radiotap.dbm_antsignal

-- returns list of SNRs stats (MIN/MAX/AVG) for each measurement
-- stored in map indexed by a string concatenated by power and rate 
-- and MIN/MAX/AVG seperated by "-"
function FXsnrAnalyser:snrs ()
    local ret = {}
    
    for _, measurement in ipairs ( self.measurements ) do

        --if ( measurement.node_name == "lede-ap" ) then

        for key, stats in pairs ( measurement.tcpdump_pcaps ) do

            local snrs = {}
        
            if ( table_size ( split ( key, "-" ) ) < 3 ) then
                print ( "ERROR: unsupported key encoding" )
                break
            end

            local rate = self:get_rate ( key )
            local power = self:get_power ( key )

            local fname = measurement.output_dir .. "/" .. measurement.node_name 
                            .. "/" .. measurement.node_name .. "-" .. key .. ".pcap"
            print ( fname )
            -- local file = io.open(fname, "wb")
            --file:write ( stats )
            --file:close()
            local ssid_m = self:read_ssid ( measurement.output_dir, measurement.node_name )
            --print ( ssid_m )
            --print ( measurement.node_name )
            --print ( "mac: " .. measurement.node_mac )
            --print ( "macs: " .. table_tostring ( measurement.opposite_macs ) )
            local cap = pcap.open_offline ( fname )
            if ( cap ~= nil ) then
	            --cap:set_filter ("type data subtype data", nooptimize)
	            --cap:set_filter ("type mgt subtype beacon", nooptimize)
            
                for capdata, timestamp, wirelen in cap.next, cap do
                    local rest = capdata
                    local pos = 0
                    local radiotap_header
                    local radiotap_data
                    radiotap_header, rest, pos = PCAP.parse_radiotap_header ( rest )
                    radiotap_data, rest, pos = PCAP.parse_radiotap_data ( rest, pos )
		            local ssid = radiotap_data [ 'ssid' ]
		            local frame_type = radiotap_data [ 'type' ]
		            local frame_subtype = radiotap_data [ 'subtype' ]
                    local sa = PCAP.mac_tostring ( radiotap_data [ 'sa' ] )
                    local da = PCAP.mac_tostring ( radiotap_data [ 'da' ] )
                    -- if ( da == "ff:ff:ff:ff:ff:ff" and ( misc.index_of ( sa, measurement.opposite_macs ) ~= nil or sa == measurement.node_mac )
                    --              or ( misc.index_of ( sa, measurement.opposite_macs ) ~= nil and sa == measurement.node_mac ) ) then
                    if ( (
                     --       ( da == "ff::ff:ff:ff:ff:ff" and ( sa == measurement.node_mac ) ) or
                     --       ( da == "ff:ff:ff:ff:ff:ff" and misc.index_of ( sa, measurement.opposite_macs ) ~= nil ) or
                            ( da == measurement.node_mac and misc.index_of ( sa, measurement.opposite_macs ) ~= nil ) or
                            ( misc.index_of ( da, measurement.opposite_macs ) ~= nil and sa == measurement.node_mac ) )
                        and frame_type + 1 == PCAP.radiotab_frametype [ "IEEE80211_FRAMETYPE_DATA" ]
                        and ( frame_subtype + 1 == PCAP.radiotap_data_frametype [ "DATA" ]
                             or  frame_subtype + 1 == PCAP.radiotap_data_frametype [ "QOS_DATA" ] ) ) then
                	    --print ( "tsft: " .. ( radiotap_header ['tsft'] or "not present" ) )
                        --print ( ssid )
                        --print ( "subtype:" .. frame_subtype )
                        --print ( "type:" .. frame_type )
                        if ( radiotap_header ['antenna_signal'] ~= nil ) then
                            print ( "antenna_signal: " .. radiotap_header ['antenna_signal'], frame_type, frame_subtype )
                        end
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
        --end
    end

    return ret
end
