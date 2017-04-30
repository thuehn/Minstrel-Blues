
local argparse = require ('argparse')
local pprint = require ('pprint')
local config = require ('Config')

require ('Measurement')

require ('FXsnrAnalyser')
require ('SNRRendererPerRate')

local parser = argparse ("analyseSNR", "Analyse and render SNR Diagram for a measurement")

parser:argument ("input", "measurement / analyse data directory", "/tmp")
parser:flag ("-t --tshark", "use tshark as pcap analyser", false )

local args = parser:parse()

local _, aps, stas = Config.read ( args.input )

for _, name in ipairs ( ( scandir ( args.input ) ) ) do

    if ( name ~= "." and name ~= ".."  and isDir ( args.input .. "/" .. name ) ) then

        print ( "read measurement: " .. name )
        local base_dir = args.input .. "/" .. name
        local keys = read_keys ( args.input )
        local all_snrs = {}
        local fname = "snr-histogram-per_rate-power.csv"
        if ( keys ~= nil ) then
            for _, key in ipairs ( keys ) do
                local snrs_fname = base_dir .. "/" .. fname
                local snrs = {}
                if ( isFile ( snrs_fname ) == false ) then

                    local measurement = Measurement.parse ( name, args.input, key )
                    --print ( measurement:__tostring () )

                    --print ( "Analyse SNR" )
                    --print ( key )
                    local analyser = FXsnrAnalyser:create ( aps, stas )
                    local snrs
                    if ( args.tshark == true ) then
                        snrs = analyser:snrs_tshark ( measurement, "radiotap.dbm_antsignal", "snrs" )
                    else
                        snrs = analyser:snrs ( measurement )
                    end
                    merge_map ( snrs, all_snrs )
                    --pprint ( snrs )
                    print ( )
                    print ( "#values: " .. table_size ( all_snrs ) )
                end
            end
        end

        local renderer = SNRRendererPerRate:create ( all_snrs )
        renderer:run ( base_dir, fname, "snr" )
    end
end
