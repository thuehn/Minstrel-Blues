
local argparse = require ('argparse')
local pprint = require ('pprint')
local config = require ('Config')

require ('Measurement')

require ('FXAnalyser')
require ('BandwidthAnalyser')
require ('BandwidthAnalyserTcpstat')
require ('RendererPerRate')

local parser = argparse ("analyseBandwidth", "Analyse and render Bandwidth Diagram for a measurement")

parser:argument ("input", "measurement / analyse data directory", "/tmp")
parser:flag ("-t --tshark", "use tshark as pcap analyser", false )
parser:flag ("-i --iperf", "use iperf output for bandwidth analyse", false )
parser:option ("-b --border", "skip values at the begin and the end of a time series", 1 )
parser:option ("-c --min_count", "discard rare values", 10 )

local args = parser:parse()

local _, aps, stas = Config.read ( args.input )

for _, name in ipairs ( ( scandir ( args.input ) ) ) do

    if ( name ~= "." and name ~= ".."  and isDir ( args.input .. "/" .. name ) ) then

        --print ( "read measurement: " .. name )
        local keys = read_keys ( args.input )
        local all_bandwidths = {}
        local fname = "bandwidth-histogram-per_rate-power.csv"
        if ( keys ~= nil ) then
            for _, key in ipairs ( keys ) do
                local measurement = Measurement.parse ( name, args.input, key )
                --print ( measurement:__tostring () )
                if ( args.iperf == true ) then
                    local analyser = BandwidthAnalyser:create ( aps, stas )
                    local bandwidths = analyser:bandwidths ( measurement, args.border, false )
                    if ( false and table_size ( bandwidths ) == 1 and bandwidths [ 1 ] == 0 ) then
                        bandwidths = analyser:bandwidths ( measurement, args.border, true )
                    end
                    merge_map ( bandwidths, all_bandwidths )
                    --pprint ( bandwidths_iperf )
                elseif ( args.tshark == true ) then
                    local analyser = FXAnalyser:create ( aps, stas )
                    local bandwidths = analyser:snrs_tshark ( measurement, args.border, "wlan_radio.data_rate", "drate" )
                    merge_map ( bandwidths, all_bandwidths )
                    --pprint ( bandwidths )
                else
                    local analyser = BandwidthTcpstatAnalyser:create ( aps, stas )
                    local bandwidths = analyser:bandwidths ( measurement, args.border )
                    merge_map ( bandwidths, all_bandwidths )
                    --pprint ( bandwidths )
                end
            end
            print ( )
            print ( "#values: " .. table_size ( all_bandwidths ) )
        end

         
        local renderer = RendererPerRate:create ( all_bandwidths )
        renderer:run ( args.input .. "/" .. name, fname, "bandwidth", "Mbit/s", args.min_count, args.border )
    end
end
