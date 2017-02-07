require ('NodeRef')

AccessPointRef = NodeRef:new()

function AccessPointRef:create ( name, ctrl )
    local o = AccessPointRef:new{ name = name, ctrl = ctrl, wifis = {}, stations = {} }
    return o
end

function AccessPointRef:__tostring() 
    local out = NodeRef.__tostring( self )

    out = out .. "\n\t"
          .. "stations: "
    if ( self.stations == {} ) then
        out = out .. " none"
    else
        for i, station in ipairs ( self.stations ) do
            if ( i ~= 1 ) then out = out .. ", " end
            out = out .. station
        end
    end

    return out
end

function AccessPointRef:add_station ( mac )
    self.stations [ #self.stations + 1 ] = mac
end

