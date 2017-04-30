
local argparse = require ('argparse')
local pprint = require ('pprint')
local config = require ('Config')

require ('Measurement')

require ('FXsnrAnalyser')
require ('BandwidthAnalyser')
require ('BandwidthAnalyserTcpstat')
require ('SNRRendererPerRate')

local parser = argparse ("analyseBandwidth", "Analyse and render Bandwidth Diagram for a measurement")

parser:argument ("input", "measurement / analyse data directory", "/tmp")
parser:flag ("-t --tshark", "use tshark as pcap analyser", false )
parser:flag ("-i --iperf", "use iperf output for bandwidth analyse", false )

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
                    local bandwidths = analyser:bandwidths ( measurement, false )
                    if ( false and table_size ( bandwidths ) == 1 and bandwidths [ 1 ] == 0 ) then
                        bandwidths_iperf = analyser:bandwidths ( measurement, true )
                    end
                    merge_map ( bandwidths, all_bandwidths )
                    --pprint ( bandwidths_iperf )
                elseif ( args.tshark == true ) then
                    local analyser = FXsnrAnalyser:create ( aps, stas )
                    local bandwidths = analyser:snrs_tshark ( measurement, "wlan_radio.data_rate", "drate" )
                    merge_map ( bandwidths, all_bandwidths )
                    --pprint ( bandwidths )
                else
                    local analyser = BandwidthTcpstatAnalyser:create ( aps, stas )
                    local bandwidths = analyser:bandwidths ( measurement )
                    merge_map ( bandwidths, all_bandwidths )
                    --pprint ( bandwidths )
                end
            end
            print ( )
            print ( "#values: " .. table_size ( all_bandwidths ) )
        end

         
        local renderer = SNRRendererPerRate:create ( all_bandwidths )
        renderer:run ( args.input .. "/" .. name, fname, "bandwidth" )
    end
end
