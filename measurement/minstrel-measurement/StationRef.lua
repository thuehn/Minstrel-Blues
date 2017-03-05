require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl, rsa_key, output_dir )
    local o = StationRef:new{ name = name, ctrl = ctrl, rsa_key = rsa_key, output_dir = output_dir }
    return o
end

function StationRef:restart_wifi( )
    self.rpc.restart_wifi ()
end
