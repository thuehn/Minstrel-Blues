local unistd = require ('posix.unistd')
require ('lpc')
require ("NodeBase")

local pid = unistd.getpid()
local ping_pid, _, _ = lpc.run ( "ping", "-c10", "127.0.0.1" )

print ( assert ( NodeBase.parent_pid ( ping_pid ) == pid ) )

local ping_pid, _, _ = lpc.run ( "ping", "-c10", "127.0.0.1" )
os.execute ( "kill " .. ping_pid )
lpc.wait ( ping_pid )
