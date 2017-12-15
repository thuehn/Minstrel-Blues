
local argparse = require ('argparse')
local pprint = require ('pprint')
--local config = require ('Config')

require ('Measurements')
require ('MeasurementOption')

require ('FXAnalyser')
require ('RendererPerRate')

local parser = argparse ("analyseSNR", "Analyse and render SNR Diagram for a measurement")

parser:argument ("input", "measurement / analyse data directory", "/tmp")
parser:flag ("-t --tshark", "use tshark as pcap analyser", false )
parser:option ("-b --border", "skip values at the begin and the end of a time series", 1 )
parser:option ("-c --min_count", "discard rare values", 10 )

local args = parser:parse()

local aps = nil
local stas = nil
local succ, res = MeasurementsOption.read_file ( args.input )
if ( succ == false ) then
    print ( "ERROR: read options file failed: " .. ( res or "unknown" ) )
    exit 1
else
    if ( res == nil or res [ "accesspoints" ] == nil ) then
        print ( "ERROR: option accesspoints not found in options file" )
        exit 1
    end
    if ( res == nil or res [ "stations" ] == nil ) then
        print ( "ERROR: option stations not found in options file" )
        exit 1
    end
    aps = res [ "accesspoints" ].value
    aps = res [ "stations" ].value
end
--local _, aps, stas = Config.read ( args.input )

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

                    local measurement = Measurements.parse ( name, args.input, key, false )
                    --print ( measurement:__tostring () )

                    --print ( "Analyse SNR" )
                    --print ( key )
                    local analyser = FXAnalyser:create ( aps, stas )
                    local snrs
                    if ( args.tshark == true ) then
                        snrs = analyser:snrs_tshark ( measurement, args.border, "radiotap.dbm_antsignal", "snrs" )
                    else
                        snrs = analyser:snrs ( measurement, args.border )
                    end
                    merge_map ( snrs, all_snrs )
                    --pprint ( snrs )
                    print ( )
                    print ( "#values: " .. table_size ( all_snrs ) )
                end
            end
        end

        local renderer = RendererPerRate:create ( all_snrs )
        renderer:run ( base_dir, fname, "snr", "dB", args.min_count, args.border )
    end
end
