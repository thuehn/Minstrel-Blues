local pprint = require ('pprint')
local misc = require ('misc')

SNRRendererPerRate = { snrs = nil
                     , power = nil
                     , rate = nil
                     }

function SNRRendererPerRate:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function SNRRendererPerRate:create ( snrs )
    local o = SNRRendererPerRate:new( { snrs = snrs } )
    return o
end

function SNRRendererPerRate:get_power ( key )
    return tonumber ( split ( key, "-" ) [1] )
end

function SNRRendererPerRate:get_rate ( key )
    return tonumber ( split ( key, "-" ) [2] )
end


function SNRRendererPerRate:run ( basedir )

--    print ( basedir )

--    pprint ( self.snrs )
--    local snrs_per_rate = {}
    local fname = basedir .. "/snr-histogram-per_rate-power.csv"
    if ( isFile ( fname ) == false ) then
        local file = io.open ( fname, "w" )
        if ( file ~= nil ) then
            file:write ( "txrate txpower snr count\n" )
            for key, snr in pairs ( self.snrs ) do
                local parts = split ( key, "-" )
                local power = parts [1]
                local rate = parts [2]
                local stat = parts [3]
                local count = nil
                if ( snr ~= nil and stat == "WAVG" and table_size ( parts ) > 3 ) then
                    count = tonumber ( parts [4] )
                    if ( count > 10 ) then
                        print ( rate, power, snr, count )
                        file:write ( rate )
                        file:write ( " " )
                        file:write ( power )
                        file:write ( " " )
                        file:write ( snr )
                        file:write ( " " )
                        file:write ( count )
                        file:write ( "\n" )
                    end
                end
--        if ( stat == "AVG" ) then
--            if ( snrs_per_rate [ rate ] == nil ) then
--                snrs_per_rate [ rate ] = {}
--            end
--            snrs_per_rate [ rate ] [ key ] = snr
            end
            file:close ()
        end
    end
    misc.execute ( "Rscript", "--vanilla", "R/rate-power_SNR-validation.R", basedir, basedir .. "/../wifi_config.txt" )

--    for rate, snrs in pairs ( snrs_per_rate ) do
--        local fname = basedir .. "/" .. "snrs-" .. rate .. ".txt"
--        local file = io.open ( fname, "w" )
--        if ( file ~= nil ) then
--            local i = 1
--            for key, snr in pairs ( snrs ) do
--                if ( i ~= 1 ) then file:write (" ") end
--                file:write (snr)
--                i = i + 1
--            end
--            file:write('\n')
--            file:close ()
--            misc.execute ( "Rscript", "--vanilla", "R/plot_snr_per_rate.R", fname ) 
--        end
--    end
--    --pprint ( snrs_per_rate )
end
