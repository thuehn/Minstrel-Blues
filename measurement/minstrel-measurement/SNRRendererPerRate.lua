local pprint = require ('pprint')
local misc = require ('misc')

SNRRendererPerRate = { values = nil
                     , power = nil
                     , rate = nil
                     }

function SNRRendererPerRate:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function SNRRendererPerRate:create ( values )
    local o = SNRRendererPerRate:new( { values = values } )
    return o
end

function SNRRendererPerRate:get_power ( key )
    return tonumber ( split ( key, "-" ) [1] )
end

function SNRRendererPerRate:get_rate ( key )
    return tonumber ( split ( key, "-" ) [2] )
end


function SNRRendererPerRate:run ( basedir, fname, field )

--    print ( basedir )

    pprint ( self.values )
    local fname = basedir .. "/" .. fname
    if ( isFile ( fname ) == false ) then
        if ( self.values ~= nil) then
            local file = io.open ( fname, "w" )
            if ( file ~= nil ) then
                file:write ( "txrate txpower value count\n" )
                for key, value in pairs ( self.values ) do
                    local parts = split ( key, "-" )
                    local power = parts [1]
                    local rate = parts [2]
                    local stat = parts [3]
                    local count = nil
                    print ( rate, power, stat, value )
                    if ( value ~= nil ) then
                        if ( stat == "WAVG" and table_size ( parts ) > 3 ) then
                            count = tonumber ( parts [4] )
                            if ( count > 10 ) then
                                print ( rate, power, value, count )
                                file:write ( rate )
                                file:write ( " " )
                                file:write ( power )
                                file:write ( " " )
                                file:write ( value )
                                file:write ( " " )
                                file:write ( count )
                                file:write ( "\n" )
                            end
                        else
                           if ( stat == "AVG" ) then
                                file:write ( rate )
                                file:write ( " " )
                                file:write ( power )
                                file:write ( " " )
                                file:write ( value )
                                file:write ( " " )
                                file:write ( "1" )
                                file:write ( "\n" )
                           end 
                        end
                    end
                end
                file:close ()
            end
        end
    end
    misc.execute ( "Rscript", "--vanilla", "R/rate-power_SNR-validation.R", basedir, basedir .. "/../wifi_config.txt", fname, field )
end
