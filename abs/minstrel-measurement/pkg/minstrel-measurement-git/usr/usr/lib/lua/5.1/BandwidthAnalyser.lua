require ('misc')
require ('parsers/iperf')

local pprint = require ('pprint')
local misc = require ('misc')

require ('Analyser')

BandwidthAnalyser = Analyser:new()

function BandwidthAnalyser:create ( aps, stas )
    local o = BandwidthAnalyser:new( { aps = aps, stas = stas } )
    return o
end

function BandwidthAnalyser:bandwidths ( measurement, border, client )
    if ( border == nil ) then border = 0 end
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
            local suffix = "client"
            if ( client == false ) then
                suffix = "server"
            end
            local fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-iperf_" .. suffix .. ".txt"
            
            print ( fname )

            if ( isFile ( fname ) == true ) then
                local file = io.open ( fname, "r" )
                local content = file:read ( "*a" )
                file:close ()
                if ( content ~= nil and content ~= "" ) then
                    local lines = split ( content, "\n" )
                    local begin_interval = 1 + border
                    local end_interval = table_size ( lines ) - border
                    for i, iperf_str in ipairs ( lines ) do
                        if ( i >= begin_interval and i <= end_interval ) then
                            local iperf = parse_iperf_client ( iperf_str )
                            if ( iperf.id ~= nil ) then
                                --pprint ( iperf )
                                bandwidths [ #bandwidths + 1 ] = iperf.bandwidth
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
