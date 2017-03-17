
local argparse = require "argparse"

require ('Measurement')

require ('FXsnrAnalyser')
require ('SNRRenderer')

local parser = argparse("netRun", "Run minstrel blues multi AP / multi STA mesurement")

parser:argument("input", "measurement / analyse data directory","/tmp")

local args = parser:parse()

local measurements = {}

for _, name in ipairs ( ( scandir ( args.input ) ) ) do

    if ( name ~= "." and name ~= ".."  and isDir ( args.input .. "/" .. name ) ) then
                       
        --if ( Config.find_node ( name, nodes ) ~= nil ) then

            local measurement = Measurement:create ( name, nil, nil, args.input )
            measurement.tcpdump_pcaps = {}
            measurements [ #measurements + 1 ] = measurement

            for _, fname in ipairs ( ( scandir ( args.input .. "/" .. name ) ) ) do

                if ( fname ~= "." and fname ~= ".."
                    and not isDir ( args.input .. "/" .. name .. "/" .. fname )
                    and isFile ( args.input .. "/" .. name .. "/" .. fname ) ) then

                    if ( string.sub ( fname, #fname - 4, #fname ) == ".pcap" ) then

                        -- lede-ap-1.pcap
                        local key = string.sub ( fname, #name + 2, #fname - 5 )
                        measurement.tcpdump_pcaps [ key ] = ""

                    elseif ( string.sub ( fname, #fname - 3, #fname ) == ".txt" ) then

                        -- lede-ap-1-regmon_stats.txt
                        if ( string.sub ( fname, #fname - 15, #fname - 4 ) == "regmon_stats" ) then
                            local key = string.sub ( fname, #name + 2, #fname - 17 )
                            measurement.regmon_stats [ key ] = ""
                        -- lede-ap-1-cpusage_stats.txt
                        elseif ( string.sub ( fname, #fname - 16, #fname - 4 ) == "cpusage_stats" ) then
                            local key = string.sub ( fname, #name + 2, #fname - 18 )
                            measurement.cpusage_stats [ key ] = ""
                        -- lede-ap-1-rc_stats-a0:f3:c1:64:81:7b.txt
                        elseif ( string.sub ( fname, #fname - 29, #fname - 22 ) == "rc_stats" ) then
                            local key = string.sub ( fname, #name + 2, #fname - 31 )
                            local station = string.sub ( fname, #name + #key + 12, #fname - 4 )
                            if (measurement.stations == nil ) then
                                measurement.stations = {}
                            end
                            local exists = false
                            for _, s in ipairs ( measurement.stations ) do
                                if ( s == station ) then
                                    exists = true
                                    break
                                end
                            end
                            measurement.rc_stats_enabled = true
                            if ( exists == false ) then
                                measurement.stations [ #measurement.stations + 1 ] = station
                            end
                            if ( measurement.rc_stats [ station ] == nil ) then
                                measurement.rc_stats [ station ] = {}
                            end
                            measurement.rc_stats [ station ] [ key ] = ""
                        end

                    end
                        
                end
            end

            measurement:read ()
            print ( measurement:__tostring () )
        --end
    end
end

print ("Analyse and plot SNR")
for _, measurement in ipairs ( measurements ) do

    local analyser = FXsnrAnalyser:create ()
    analyser:add_measurement ( measurement )
    local snrs = analyser:snrs ()
    pprint ( snrs )
    --print ( )

    local renderer = SNRRenderer:create ( snrs )

    local dirname = args.input .. "/" .. measurement.node_name
    renderer:run ( dirname )

end
