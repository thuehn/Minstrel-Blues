
-- The script starts a measurement control node 

require ('ControlNode')
require ('rpc')
local argparse = require ('argparse')

local parser = argparse("runControl", "Run mintrel measurement control node.")
 
parser:option ("-C --port", "RPC port", "12346" )
parser:option ("-L --log_port", "Logging port", "12347" )
parser:option ("--log_ip", "Logging ip address" )

parser:option ("--ctrl_if", "Control Interface name", "eth0" )

local args = parser:parse ()

if ( args.log_ip == nil ) then
    print ( parser:get_usage() )
end

local node = ControlNode:create ( "Control", args.ctrl_if, args.port, args.log_ip, args.log_port )

function get_ctrl_addr ( ... ) return node:get_ctrl_addr ( ... ) end
function add_ap ( ... ) return node:add_ap ( ... ) end
function add_sta ( ... ) return node:add_sta ( ... ) end
function nodes ( ... ) return node:nodes ( ... ) end
function find_node ( ... ) return node:find_node ( ... ) end
function reachable ( ... ) return node:reachable ( ... ) end
function start ( ... ) return node:start ( ... ) end
function connect ( ... ) return node:connect ( ... ) end
function disconnect ( ... ) return node:disconnect ( ... ) end
function run_experiment ( ... ) return node:run_experiment ( ... ) end
function run_experiments ( ... ) return node:run_experiments ( ... ) end
function stop ( ... ) return node:stop ( ... ) end
function __tostring ( ... ) return node:__tostring ( ... ) end
function get_pid ( ... ) return node:get_pid ( ... ) end
function kill ( ... ) return node:kill ( ... ) end
function get_logger_addr ( ...  ) return node:get_logger_addr ( ... ) end

-- make all functions available via RPC
print ( node )
node:run ( args.port )
