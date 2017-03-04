
require ('pcap')
require ('parsers/radiotap')

Analyser = { measurements = nil
           }

function Analyser:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Analyser:create ()
    local o = Analyser:new( {} )
    o.measurements = {}
    return o
end

function Analyser:add_measurement ( m )
    self.measurements [ #self.measurements + 1 ] = m
end

-- duplicate of experiment:get_rate
function Analyser:get_rate( key )
    return split ( key, "-" ) [1]
end

-- duplicate of experiment:get_rate
function Analyser:get_power( key )
    return split ( key, "-" ) [2]
end

function Analyser.avg ( t )
    local sum = 0
    local count = 0
    
    for _, v in ipairs ( t ) do
        if type ( v ) == 'number' then
            sum = sum + v
            count = count + 1
        end
    end

    return (sum / count)
end

-- returns list of SNRs stats (MIN/MAX/AVG) for each measurement
-- stored in map indexed by a string concatenated by power and rate 
-- and MIN/MAX/AVG seperated by "-"
function Analyser:snrs ()
    local ret = {}
    
    for _, measurement in ipairs ( self.measurements ) do

        local snrs = {}
        local min_snr
        local max_snr
        local avg_snr

        for key, stats in pairs ( measurement.tcpdump_pcaps ) do
        
            local rate = self:get_rate ( key )
            local power = self:get_power ( key )

            local fname = "/tmp/" .. measurement.node_name .. "-" .. key .. ".pcap"
            local file = io.open(fname, "wb")
            file:write ( stats )
            file:close()
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
                    if ( ssid == "LEDE" ) then
                        --print ( "timestamp: " .. timestamp )
                	    --print ( "tsft: " .. ( radiotap_header ['tsft'] or "not present" ) )
        			    print ( "antenna_signal: " .. ( radiotap_header ['antenna_signal'] or "not present" ) )
                        if ( radiotap_header ['antenna_signal'] ~= nil ) then
                            snrs [ #snrs + 1 ] = radiotap_header ['antenna_signal']
                        end
                    end
                end

                cap:close()
            else
                print ("Analyser: pcap open failed: " .. fname)
            end

            if ( table_size ( snrs ) > 0 ) then
                ret [ power .. "-" .. rate .. "-MIN" ] = math.min ( unpack ( snrs ) )
                ret [ power .. "-" .. rate .. "-MAX" ] = math.max ( unpack ( snrs ) )
                ret [ power .. "-" .. rate .. "-AVG" ] = self:avg ( snrs )
            end
        end
    end

    return ret
end
