require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl, port )
    local o = StationRef:new{ name = name, ctrl = ctrl, wifis = {}, addrs = {}, macs = {}, refs = {} }
    return o
end

function StationRef:restart_wifi( )
    self.rpc.restart_wifi ()
end
