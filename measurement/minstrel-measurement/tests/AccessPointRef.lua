
require 'AccessPointRef'
local misc = require 'misc'
local ps = require ('posix.signal') --kill
local lpc = require 'lpc'
local posix = require ('posix') -- sleep
local pprint = require ('pprint')

pid_l, in_l, out_l = misc.spawn ( "lua", "bin/runLogger.lua", "/tmp/m.log", "--use_stdout" )
pid_n, in_n, out_n = misc.spawn ( "lua", "bin/runNode.lua", "--name", "localhost", "--ctrl_if", "lo"
                                , "--log_ip", "127.0.0.1", "--log_port", 12347 )

ap = AccessPointRef:create ( "localhost", "lo", nil, "/tmp", "127.0.0.1", 12347 )
ap:connect ( 12346, print )

assert ( ap.ctrl_net_ref.addr == "127.0.0.1" )
assert ( ap.ctrl_net_ref.iface == "lo" )
assert ( ap.ctrl_net_ref.name == "localhost" )

assert ( table_size ( ap.radios ) > 0 )

for phy, radio in pairs ( ap.radios ) do
    pprint ( phy )
    ap:set_phy ( phy )
    local iw_info = ap.rpc.get_iw_info ( phy )
    print ( iw_info )
    assert ( iw_info ~= nil )
end

ap:disconnect ()

ps.kill ( pid_n, ps.SIGKILL )
ps.kill ( pid_l, ps.SIGKILL )

_ = lpc.wait ( pid_n )
_ = lpc.wait ( pid_l )

print ( "node: " .. out_l:read("*a") )
print ( "log:" .. out_n:read("*a") )

out_l:close()
out_n:close()
in_l:close()
in_n:close()
