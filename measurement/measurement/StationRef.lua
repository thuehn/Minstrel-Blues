require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl, port )
    local o = StationRef:new{ name = name, ctrl = ctrl, wifis = {}, addrs = {}, macs = {} }
    return o
end
