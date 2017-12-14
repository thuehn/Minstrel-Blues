require ('misc')

local pprint = require ('pprint')
local misc = require ('misc')

require ('Analyser')

BandwidthTcpstatAnalyser = Analyser:new()

function BandwidthTcpstatAnalyser:create ( aps, stas )
    local o = BandwidthTcpstatAnalyser:new ( { aps = aps, stas = stas } )
    return o
end

-- border: number of values to skip in analysis
--         the first and the last <border> values are sipped
function BandwidthTcpstatAnalyser:bandwidths ( measurement, border )
    if ( border == nil ) then border = 0 end
    local ret = {}
    
    local base_dir = measurement.output_dir .. "/" .. measurement.node_name

    for key, _ in pairs ( measurement.tcpdump_meas ) do
    --for key, stats in pairs ( measurement.tcpdump_pcaps ) do
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
                --print ( content )
                if ( content ~= nil and content ~= "" ) then
                    local lines = split ( content, "\n" )
                    local begin_interval = 1 + border
                    local end_interval = table_size ( lines ) - border
                    for i, bandwidth_str in ipairs ( lines ) do
                        --pprint ( bandwidth_str )
                        if ( bandwidth_str ~= "" ) then
                            if ( i >= begin_interval and i <= end_interval ) then
                                local parts = split ( bandwidth_str , " " )
                                local ts = parts [ 1 ]
                                local id = parts [ 2 ]
                                local bandwidth = parts [ 3 ]
                                bandwidths [ #bandwidths + 1 ] = tonumber ( bandwidth / 1024 / 1024 )
                            end
                        end
                    end
                    if ( table_size ( bandwidths ) == 0 ) then
                        bandwidths = { 0 }
                    end
                    self:write ( bandwidths_fname, bandwidths )
                end
            end
        else
            print ( bandwidths_fname )
            bandwidths = self:read ( bandwidths_fname )
        end
        --pprint ( bandwidths )

        local rate = self:get_rate ( key )
        local power = self:get_power ( key )
        local bandwidths_stats = self:calc_stats ( bandwidths, power, rate )
        merge_map ( bandwidths_stats, ret )
    end

    return ret
end
