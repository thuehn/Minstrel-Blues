local unistd = require ('posix.unistd')
require ('spawn_pipe')
require ("parsers/ex_process")
require ("parentpid")

local pid = unistd.getpid()
local p_ping = spawn_pipe("ping", "-c10", "127.0.0.1")
local ping_pid = parse_process ( p_ping['proc']:__tostring() )

print ( assert ( parent_pid ( ping_pid['pid']) == pid))
spawn_pipe("kill", ping_pid['pid'])
p_ping['proc']:wait()
