require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl )
    local o = StationRef:new{ name = name, ctrl = ctrl, wifis = {} }
    return o
end
