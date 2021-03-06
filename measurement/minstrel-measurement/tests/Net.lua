require 'Net'

local addr, msg = Net.get_addr ( "lo" )
assert ( addr ~= nil )
assert ( msg == nil )

local dig, msg = Net.lookup ( "localhost" )
assert ( dig.addr [ 1 ] == "127.0.0.1" )
assert ( msg == nil )

local name, msg = Net.get_hostname ()
assert ( name ~= nil )
assert ( msg == nil )

