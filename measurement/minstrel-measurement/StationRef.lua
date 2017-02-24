require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl, rsa_key )
    local o = StationRef:new{ name = name, ctrl = ctrl, rsa_key = rsa_key }
    return o
end

function StationRef:restart_wifi( )
    self.rpc.restart_wifi ()
end
