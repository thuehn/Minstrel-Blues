
local misc = require ('misc')
local posix = require ('posix') -- sleep

require ('AccessPointRef')

MeshNodeRef = AccesspointRef:new()

function MeshNodeRef:create ( name, lua_bin, ctrl_if, rsa_key, output_dir, log_addr, log_port )
    local ctrl_net_ref = NetIfRef:create ( ctrl_if )
    ctrl_net_ref:set_addr ( name )

    local o = MeshNodeRef:new { name = name
                              , lua_bin = lua_bin
                              , ctrl_net_ref = ctrl_net_ref
                              , rsa_key = rsa_key
                              , output_dir = output_dir
                              , refs = {}
                              , stations = {}
                              , log_addr = log_addr
                              , log_port = log_port
                                }
    return o
end
