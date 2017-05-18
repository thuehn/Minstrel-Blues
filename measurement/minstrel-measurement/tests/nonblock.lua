local pprint = require ('pprint')
local misc = require ('misc')
local ps = require ('posix.signal') --kill
local lpc = require ('lpc')
local posix = require ('posix') -- sleep

local phy = "phy12"

_, exit_code = misc.execute ( "iw", "dev", "mon0", "info" )
if ( exit_code ~= 0 ) then
    _, exit_code = misc.execute ( "iw", "phy", phy, "interface", "add", "mon0", "type", "monitor" )
end
_, exit_code = misc.execute ("ifconfig", "mon0", "up")

pid, stdin, stdout = misc.spawn ( "/usr/sbin/tcpdump", "-i", "mon0", "-s", 150, "-U", "-w", "-" )

posix.sleep ( 3 )

dump = ""

out = misc.read_nonblock ( stdout, 500, 1024 )
pprint ( out )
if ( out ~= nil ) then
    print ( string.len ( out ) )
    dump = dump .. out
end

posix.sleep ( 3 )

out = misc.read_nonblock ( stdout, 500, 1024 )
if ( out ~= nil ) then
    print ( string.len ( out ) )
    dump = dump .. out
end

posix.sleep ( 3 )

out = misc.read_nonblock ( stdout, 500, 1024 )
if ( out ~= nil ) then
    print ( string.len ( out ) )
    dump = dump .. out
end

if ( ps.kill ( pid ) ) then
    exit_code = lpc.wait ( pid )
end

out = misc.read_nonblock ( stdout, 500, 1024 )
if ( out ~= nil ) then
    print ( string.len ( out ) )
    dump = dump .. out
end

pprint ( dump )
