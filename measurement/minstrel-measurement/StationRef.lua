require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl, port, rsa_key )
    --fixme: try NodeRef:create
    local o = StationRef:new{ name = name, ctrl = ctrl, rsa_key = rsa_key, phys = {}, addrs = {}, macs = {}, refs = {} }
    return o
end

function StationRef:restart_wifi( )
    self.rpc.restart_wifi ()
end
