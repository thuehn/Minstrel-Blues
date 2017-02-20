require ('NodeRef')
require ('misc')

local port = 12346
local ctrl = NetIF:create("lo0" , "127.0.0.1" )
local node_ref = NodeRef:create( "sinope", ctrl, port )

assert ( node_ref.rpc == nil)
assert ( table_size ( node_ref.phys ) == 0 )
assert ( table_size ( node_ref.addrs ) == 0 )
assert ( table_size ( node_ref.macs ) == 0 )

-- TODO: start a node and test init
