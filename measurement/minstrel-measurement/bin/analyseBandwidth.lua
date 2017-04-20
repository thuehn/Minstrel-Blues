
local argparse = require ('argparse')
local pprint = require ('pprint')
local config = require ('Config')

require ('Measurement')

require ('BandwidthAnalyser')

local parser = argparse ("analyseBandwidth", "Analyse and render Bandwidth Diagram for a measurement")

parser:argument ("input", "measurement / analyse data directory", "/tmp")

local args = parser:parse()

local _, aps, stas = Config.read ( args.input )

for _, name in ipairs ( ( scandir ( args.input ) ) ) do

    if ( name ~= "." and name ~= ".."  and isDir ( args.input .. "/" .. name ) ) then

        print ( "read measurement: " .. name )
        local keys = read_keys ( args.input )
        local all_bandwidths = {}
        for _, key in ipairs ( keys ) do
            local measurement = Measurement.parse ( name, args.input, key )
            --print ( measurement:__tostring () )

            --print ( "Analyse SNR" )
            --print ( key )
            local analyser = BandwidthAnalyser:create ( aps, stas )
            local bandwidths = analyser:bandwidths ( measurement )
            merge_map ( bandwidths, all_bandwidths )
            --pprint ( snrs )
        end
        print ( )
        print ( "#values: " .. table_size ( all_bandwidths ) )

        --local renderer = SNRRendererPerRate:create ( all_snrs )
        --renderer:run ( args.input .. "/" .. name )
    end
end
