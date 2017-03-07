
require ('misc')
require ('pcap')
require ('parsers/radiotap')

DYNsnrAnalyser = { measurements = nil
                 }

function DYNsnrAnalyser:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function DYNsnrAnalyser:create ()
    local o = DYNsnrAnalyser:new( {} )
    o.measurements = {}
    return o
end

function DYNsnrAnalyser:add_measurement ( m )
    self.measurements [ #self.measurements + 1 ] = m
end

function DYNsnrAnalyser:min ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local min = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v < min ) then min = v end
    end
    return min
end

function DYNsnrAnalyser:max ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local max = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v > max ) then max = v end
    end
    return max
end

function DYNsnrAnalyser:avg ( t )
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

-- returns list of SNRs stats (MIN/MAX/AVG) for each measurement
-- stored in map indexed by a string concatenated by power and rate 
-- and MIN/MAX/AVG seperated by "-"
function DYNsnrAnalyser:snrs ()
    local ret = {}
    
    for _, measurement in ipairs ( self.measurements ) do

        local snrs = {}
        local min_snr
        local max_snr
        local avg_snr

        for key, stats in pairs ( measurement.tcpdump_pcaps ) do
        
            print ( key ) 
            if ( table_size ( split ( key, "-" ) ) ~= 1 ) then break end
        
            local power
            local rate

            local fname = measurement.output_dir .. "/" .. measurement.node_name 
                            .. "/" .. measurement.node_name .. "-" .. key .. ".pcap"
            -- local file = io.open(fname, "wb")
            --file:write ( stats )
            --file:close()
            local cap = pcap.open_offline( fname )
            if (cap ~= nil) then
	            cap:set_filter ("type mgt subtype beacon", nooptimize)
            
                for capdata, timestamp, wirelen in cap.next, cap do
                    local rest = capdata
                    local radiotap_header
                    local radiotap_data
                    radiotap_header, rest = PCAP.parse_radiotap_header ( rest )
                    radiotap_data, rest = PCAP.parse_radiotap_data ( rest )
		            local ssid = radiotap_data['ssid']
                    if ( ssid == "Sagmegar" ) then
                	    --print ( "tsft: " .. ( radiotap_header ['tsft'] or "not present" ) )
                        --print ( ssid )
                        
                        power = radiotap_header ['tx_power'] or 25
                        local snr = radiotap_header ['antenna_signal']
                        rate = radiotap_header ['rate'] or 128

                        --print ( "antenna_signal: " .. ( snr or "not present" ) )
                        --print ( "rate: " .. ( rate or "not present" ) )
                        --print ( "tx_power: " .. ( power or "not present" ) )

                        if ( snr ~= nil ) then
                            snrs [ #snrs + 1 ] = snr
                        end
                    end
                end

                cap:close()
            else
                print ("DYNsnrAnalyser: pcap open failed: " .. fname)
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
